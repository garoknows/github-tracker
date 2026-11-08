import Foundation
import Testing
@testable import TrackerKit

/// Answers requests from a table and records what was asked. No real network.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    struct Reply {
        var status = 200
        var body = ""
        var headers: [String: String] = [:]
        /// When set, the request fails like a dropped connection instead of answering.
        var failure: URLError.Code?
        /// Seconds to wait before answering, like a slow network.
        var delay: Double = 0
    }

    private let lock = NSLock()
    private var routes: [(String, Reply)] = []
    private(set) var requests: [URLRequest] = []
    var offline = false

    func on(_ urlContains: String, _ reply: Reply) {
        lock.withLock { routes.insert((urlContains, reply), at: 0) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (reply, isOffline): (Reply?, Bool) = lock.withLock {
            requests.append(request)
            let url = request.url!.absoluteString
            return (routes.first { url.contains($0.0) }?.1, offline)
        }
        if isOffline { throw URLError(.notConnectedToInternet) }
        let r = reply ?? Reply(status: 404, body: "Not Found")
        if r.delay > 0 { try await Task.sleep(for: .seconds(r.delay)) }
        if let failure = r.failure { throw URLError(failure) }
        let response = HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: r.headers)!
        return (Data(r.body.utf8), response)
    }

    var urls: [String] { lock.withLock { requests.map { $0.url!.absoluteString } } }
}

final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    init(_ d: Date) { value = d }
    var now: Date { lock.withLock { value } }
    func advance(_ s: TimeInterval) { lock.withLock { value = value.addingTimeInterval(s) } }
}

func tempCache() -> DiskCache {
    DiskCache(directory: FileManager.default.temporaryDirectory
        .appendingPathComponent("TrackerKitTests-\(UUID().uuidString)", isDirectory: true))
}

func stubbedGaro(_ t: FakeTransport) throws {
    t.on("/users/garoknows/contributions", .init(body: try fixture("calendar_active")))
    t.on("tab=contributions", .init(body: try fixture("overview_on")))
    t.on("api.github.com/users/garoknows", .init(body: #"{"login":"garoknows","name":"Garo","avatar_url":"https://avatars.githubusercontent.com/u/1","html_url":"https://github.com/garoknows"}"#))
}

@Suite("Client and loader")
struct NetworkTests {
    @Test func sendsUserAgentAndOnlyTalksToGitHub() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore())
        let result = await loader.load("garoknows")
        #expect(result.error == nil)
        #expect(result.snapshot?.calendar.total == 93)
        #expect(result.snapshot?.profile.displayName == "Garo")
        #expect(result.snapshot?.overview.overview?.commits == 53)
        for r in t.requests {
            #expect(r.value(forHTTPHeaderField: "User-Agent") == GitHubClient.userAgent)
            #expect(GitHubClient.allowedHosts.contains(r.url!.host!))
            #expect(r.value(forHTTPHeaderField: "Authorization") == nil)
        }
        #expect(t.requests.contains { $0.value(forHTTPHeaderField: "X-Requested-With") == "XMLHttpRequest" })
    }

    @Test func unknownUser() async throws {
        let t = FakeTransport()
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore())
        await #expect(throws: TrackerError.userNotFound("nobody-zz9")) { try await loader.validate("nobody-zz9") }
        let r = await loader.load("nobody-zz9")
        #expect(r.snapshot == nil)
        #expect(r.error?.errorDescription == "No GitHub user named 'nobody-zz9'. Check the spelling.")
    }

    @Test func offlineFallsBackToCacheWithTimestamp() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let loader = ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: tempCache(),
                                   tokens: MemoryTokenStore(), now: { clock.now })
        let first = await loader.load("garoknows")
        #expect(first.error == nil)

        t.offline = true
        clock.advance(7200)
        let second = await loader.load("garoknows")
        #expect(second.error == .offline)
        #expect(second.isOffline)
        #expect(second.snapshot?.calendar.total == 93)
        #expect(Format.age(since: second.snapshot!.fetchedAt, now: clock.now) == "2 hr ago")
    }

    @Test func profileCachedFor24Hours() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let cache = tempCache()
        let loader = ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: cache,
                                   tokens: MemoryTokenStore(), now: { clock.now })
        func restCalls() -> Int { t.urls.filter { $0.contains("api.github.com/users/") }.count }

        _ = await loader.load("garoknows")
        #expect(restCalls() == 1)
        clock.advance(23 * 3600)
        _ = await loader.load("garoknows")
        #expect(restCalls() == 1)
        #expect(cache.freshProfile(for: "garoknows", now: clock.now) != nil)
        clock.advance(2 * 3600)
        #expect(cache.freshProfile(for: "garoknows", now: clock.now) == nil)
        _ = await loader.load("garoknows")
        #expect(restCalls() == 2)
    }

    @Test func rateLimitBacksOffWithoutHammering() async throws {
        let t = FakeTransport()
        t.on("/users/x/contributions", .init(status: 429, headers: ["Retry-After": "120"]))
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let client = GitHubClient(transport: t, now: { clock.now })

        await #expect(throws: TrackerError.rateLimited(until: clock.now.addingTimeInterval(120))) {
            _ = try await client.calendarHTML(for: "x")
        }
        // While blocked, no request leaves the Mac.
        await #expect(throws: TrackerError.self) { _ = try await client.calendarHTML(for: "x") }
        #expect(t.requests.count == 1)

        clock.advance(121)
        t.on("/users/x/contributions", .init(body: try fixture("calendar_empty")))
        _ = try await client.calendarHTML(for: "x")
        #expect(t.requests.count == 2)
    }

    @Test func restRateLimitUsesResetHeader() async throws {
        let t = FakeTransport()
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        t.on("api.github.com/users/y", .init(status: 403, headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1800000600"]))
        let client = GitHubClient(transport: t, now: { clock.now })
        await #expect(throws: TrackerError.rateLimited(until: Date(timeIntervalSince1970: 1_800_000_600))) {
            _ = try await client.profile(for: "y", token: nil)
        }
    }

    @Test func exponentialBackoffWithoutHeaders() async throws {
        let t = FakeTransport()
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        t.on("/users/z/contributions", .init(status: 429))
        let client = GitHubClient(transport: t, now: { clock.now })
        var waits: [TimeInterval] = []
        for _ in 0..<3 {
            do { _ = try await client.calendarHTML(for: "z") } catch TrackerError.rateLimited(let until) {
                waits.append(until.timeIntervalSince(clock.now))
                clock.advance(until.timeIntervalSince(clock.now) + 1)
            }
        }
        #expect(waits == [60, 120, 240])
    }

    @Test func tokenUnlocksGraphQLWhenPublicOverviewMissing() async throws {
        let t = FakeTransport()
        t.on("/users/octo/contributions", .init(body: try fixture("calendar_active")))
        t.on("tab=contributions", .init(body: "<div>unexpected</div>"))
        t.on("api.github.com/graphql", .init(body: """
        {"data":{"user":{"login":"octo","name":null,"avatarUrl":null,"url":"https://github.com/octo","contributionsCollection":{
          "totalCommitContributions":3,"totalIssueContributions":1,"totalPullRequestContributions":0,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":4,"weeks":[]}}}}}
        """))
        let tokens = MemoryTokenStore("test-token-not-real")
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: tokens)
        let r = await loader.load("octo")
        #expect(r.snapshot?.overview == .available(ActivityOverview(commits: 75, issues: 25, pullRequests: 0, codeReview: 0), source: .graphQL))
        // Calendar still comes from the public page.
        #expect(r.snapshot?.calendar.total == 93)
        // The token only goes to api.github.com.
        #expect(t.requests.contains { $0.value(forHTTPHeaderField: "Authorization") != nil })
        for req in t.requests where req.value(forHTTPHeaderField: "Authorization") != nil {
            #expect(req.url?.host == "api.github.com")
        }

        // Without a token, the card shows the placeholder instead.
        let noToken = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore())
        #expect(await noToken.load("octo").snapshot?.overview == .needsToken)
    }

    @Test func graphQLCalendarFallbackWhenMarkupChanges() async throws {
        let t = FakeTransport()
        t.on("/users/octo/contributions", .init(body: "<html>redesigned</html>"))
        t.on("tab=contributions", .init(body: try fixture("overview_off")))
        t.on("api.github.com/graphql", .init(body: """
        {"data":{"user":{"login":"octo","name":"Octo","avatarUrl":null,"url":"https://github.com/octo","contributionsCollection":{
          "totalCommitContributions":1,"totalIssueContributions":0,"totalPullRequestContributions":0,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":1,"weeks":[{"contributionDays":[{"date":"2026-10-26","contributionCount":1,"contributionLevel":"FIRST_QUARTILE"}]}]}}}}}
        """))
        let withToken = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore("t"))
        let r = await withToken.load("octo")
        #expect(r.snapshot?.calendar.total == 1)
        #expect(r.snapshot?.overview == .off)

        let noToken = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore())
        #expect(await noToken.load("octo").error == .markupChanged)
    }

    @Test func refusesOtherHosts() async throws {
        let t = FakeTransport()
        let client = GitHubClient(transport: t)
        // Lookalike hosts, credentials-in-URL tricks and plain other hosts never leave the Mac.
        for raw in ["https://evil.example/users/x/contributions",
                    "https://github.com.evil.example/users/x/contributions",
                    "https://api.github.com@evil.example/graphql",
                    "https://evil.example/?https://api.github.com/"] {
            let url = try #require(URL(string: raw))
            await #expect(throws: TrackerError.blockedHost(url.host!)) {
                _ = try await client.request(url, headers: ["Authorization": "Bearer not-real"], notFound: nil)
            }
            await #expect(throws: TrackerError.blockedHost(raw)) { _ = try await client.url(raw) }
        }
        // GitHub's own hosts over plain http are refused too, so a token can't travel unencrypted.
        let http = "http://api.github.com/graphql"
        await #expect(throws: TrackerError.blockedHost(http)) {
            _ = try await client.request(URL(string: http)!, headers: ["Authorization": "Bearer not-real"], notFound: nil)
        }
        await #expect(throws: TrackerError.blockedHost(http)) { _ = try await client.url(http) }
        #expect(t.requests.isEmpty)

        // The allowlist really is what stopped them: the same call to GitHub goes out.
        t.on("api.github.com/rate_limit", .init(body: "{}"))
        _ = try await client.request(URL(string: "https://api.github.com/rate_limit")!, headers: [:], notFound: nil)
        #expect(t.requests.count == 1)
    }

}

/// A brief rate limit or network drop must not replace a good Activity overview with "Add a free token".
@Suite("Activity overview survives temporary errors")
struct OverviewResilienceTests {
    enum Glitch: String, CaseIterable, Sendable {
        case tooManyRequests, rateLimit403, serverError, offline, timeout

        var reply: FakeTransport.Reply {
            switch self {
            case .tooManyRequests: .init(status: 429, headers: ["Retry-After": "60"])
            case .rateLimit403: .init(status: 403, headers: ["x-ratelimit-remaining": "0", "x-ratelimit-reset": "1800003660"])
            case .serverError: .init(status: 502)
            case .offline: .init(failure: .notConnectedToInternet)
            case .timeout: .init(failure: .timedOut)
            }
        }
    }

    func setUp() throws -> (FakeTransport, ProfileLoader, DiskCache, Clock) {
        let t = FakeTransport()
        try stubbedGaro(t)
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let cache = tempCache()
        let loader = ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: cache,
                                   tokens: MemoryTokenStore(), now: { clock.now })
        return (t, loader, cache, clock)
    }

    @Test(arguments: Glitch.allCases)
    func keepsCachedOverview(_ glitch: Glitch) async throws {
        let (t, loader, cache, clock) = try setUp()
        let good = try #require(await loader.load("garoknows").snapshot?.overview)
        #expect(good.overview?.commits == 53)

        clock.advance(1800)
        t.on("tab=contributions", glitch.reply)
        let r = await loader.load("garoknows")
        #expect(r.snapshot?.overview == good, "\(glitch) replaced the overview")
        #expect(r.snapshot?.calendar.total == 93)
        #expect(r.overviewError != nil, "the kept overview should be marked as stale")
        // What's saved to disk is still the good overview, not a token prompt.
        #expect(cache.snapshot(for: "garoknows")?.overview == good)
    }

    @Test(arguments: Glitch.allCases)
    func neverClaimsATokenIsNeededForATemporaryError(_ glitch: Glitch) async throws {
        let (t, loader, _, _) = try setUp()
        t.on("tab=contributions", glitch.reply)
        let r = await loader.load("garoknows")
        #expect(r.snapshot?.calendar.total == 93)
        #expect(r.snapshot?.overview == .unavailable)
        #expect(r.overviewError != nil)
    }

    @Test func retriesAfterTheBackoff() async throws {
        let (t, loader, _, clock) = try setUp()
        _ = await loader.load("garoknows")
        t.on("tab=contributions", Glitch.tooManyRequests.reply)
        clock.advance(1800)
        #expect(await loader.load("garoknows").overviewError != nil)

        // While GitHub's Retry-After is running, nothing is sent to github.com.
        let sent = t.requests.count
        _ = await loader.load("garoknows")
        #expect(t.requests.count == sent)

        clock.advance(61)
        t.on("tab=contributions", .init(body: try fixture("overview_commits_only")))
        let r = await loader.load("garoknows")
        #expect(r.error == nil)
        #expect(r.overviewError == nil)
        #expect(r.snapshot?.overview.overview?.commits == 100)
    }

    @Test func tokenPathKeepsCachedOverviewWhenGraphQLIsRateLimited() async throws {
        let t = FakeTransport()
        t.on("/users/octo/contributions", .init(body: try fixture("calendar_active")))
        t.on("tab=contributions", .init(body: "<div>unexpected</div>"))
        t.on("api.github.com/graphql", .init(body: """
        {"data":{"user":{"login":"octo","name":null,"avatarUrl":null,"url":"https://github.com/octo","contributionsCollection":{
          "totalCommitContributions":3,"totalIssueContributions":1,"totalPullRequestContributions":0,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":4,"weeks":[]}}}}}
        """))
        let clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))
        let loader = ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: tempCache(),
                                   tokens: MemoryTokenStore("test-token-not-real"), now: { clock.now })
        let good = try #require(await loader.load("octo").snapshot?.overview)
        #expect(good.overview?.commits == 75)

        clock.advance(1800)
        t.on("api.github.com/graphql", .init(status: 403, headers: ["x-ratelimit-remaining": "0"]))
        let r = await loader.load("octo")
        #expect(r.snapshot?.overview == good)
        #expect(r.overviewError != nil)
    }

    @Test func unparseablePageStillOffersTheTokenPath() async throws {
        let (t, loader, _, _) = try setUp()
        t.on("tab=contributions", .init(body: "<html>login wall</html>"))
        let r = await loader.load("garoknows")
        #expect(r.snapshot?.overview == .needsToken)
        #expect(r.overviewError == nil)
    }
}
