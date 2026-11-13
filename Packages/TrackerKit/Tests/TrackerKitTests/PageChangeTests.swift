import Foundation
import Testing
@testable import TrackerKit

/// GitHub's real markup with every hover text (the per-day counts) removed, as if GitHub changed it.
func withoutTooltips(_ html: String) -> String {
    html.replacingOccurrences(of: "<tool-tip\\b[^>]*>[^<]*</tool-tip>", with: "", options: .regularExpression)
}

/// When GitHub changes its page, say so, and never trade good saved numbers for guesses.
@Suite("GitHub changed its page")
struct PageChangeTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func parserRefusesToGuessCountsFromColors() throws {
        let html = withoutTooltips(try fixture("calendar_active"))
        #expect(!html.contains("<tool-tip"))
        #expect(throws: CalendarParser.Failure.countsUnreadable) { try CalendarParser.parse(html) }
    }

    @Test func estimatesOnlyWhenAskedTo() throws {
        let cal = try CalendarParser.parse(withoutTooltips(try fixture("calendar_active")), estimateMissingCounts: true)
        #expect(cal.days.count == 366)
        #expect(cal.days.allSatisfy { $0.count == ($0.level > 0 ? 1 : 0) })
        // The heading is a separate element, so the total still comes from GitHub.
        #expect(cal.total == 93)
    }

    @Test func emptyCalendarNeedsNoHoverText() throws {
        // Nobody contributed, so there's nothing to count and nothing is missing.
        let cal = try CalendarParser.parse(withoutTooltips(try fixture("calendar_empty")))
        #expect(cal.days.allSatisfy { $0.count == 0 })
    }

    @Test func olderDataCountMarkupStillWorks() throws {
        let html = #"<td class="ContributionCalendar-day" data-date="2026-10-26" data-level="2" data-count="4"></td>"#
        #expect(try CalendarParser.parse(html).days.first?.count == 4)
    }

    func loader(_ t: FakeTransport, cache: DiskCache, clock: Clock, tokens: TokenStore = MemoryTokenStore()) -> ProfileLoader {
        ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: cache, tokens: tokens, now: { clock.now })
    }

    @Test func keepsGoodSavedDataInsteadOfGuessing() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let clock = Clock(start)
        let cache = tempCache()
        let l = loader(t, cache: cache, clock: clock)
        let good = try #require(await l.load("garoknows").snapshot)

        clock.advance(7200)
        t.on("/users/garoknows/contributions", .init(body: withoutTooltips(try fixture("calendar_active"))))
        let r = await l.load("garoknows")
        #expect(r.error == .countsUnreadable)
        #expect(!r.estimated)
        #expect(r.snapshot == good)
        #expect(cache.snapshot(for: "garoknows") == good, "the good saved data was overwritten")
    }

    @Test func withNothingSavedShowsAnEstimateButNeverSavesIt() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        t.on("/users/garoknows/contributions", .init(body: withoutTooltips(try fixture("calendar_active"))))
        let cache = tempCache()
        let r = await loader(t, cache: cache, clock: Clock(start)).load("garoknows")
        #expect(r.error == .countsUnreadable)
        #expect(r.estimated)
        let snap = try #require(r.snapshot)
        #expect(snap.calendar.days.count == 366)
        #expect(snap.calendar.total == 93)
        #expect(cache.snapshot(for: "garoknows") == nil, "a guess must never become the saved copy")
    }

    @Test func aTokenReadsTheRealCountsInstead() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        t.on("/users/garoknows/contributions", .init(body: withoutTooltips(try fixture("calendar_active"))))
        t.on("api.github.com/graphql", .init(body: """
        {"data":{"user":{"login":"garoknows","name":null,"avatarUrl":null,"url":"https://github.com/garoknows","contributionsCollection":{
          "totalCommitContributions":7,"totalIssueContributions":0,"totalPullRequestContributions":0,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":7,"weeks":[{"contributionDays":[{"date":"2026-10-26","contributionCount":7,"contributionLevel":"FOURTH_QUARTILE"}]}]}}}}}
        """))
        let cache = tempCache()
        let r = await loader(t, cache: cache, clock: Clock(start), tokens: MemoryTokenStore("test-token-not-real")).load("garoknows")
        #expect(r.error == nil)
        #expect(!r.estimated)
        #expect(r.snapshot?.calendar.days.last?.count == 7)
        #expect(cache.snapshot(for: "garoknows")?.calendar.total == 7)
    }
}

/// The note under a card says what actually happened, not always "Offline".
@MainActor
@Suite("Card messages")
struct CardMessageTests {
    static let fetched = Date(timeIntervalSince1970: 1_800_000_000)
    let later = fetched.addingTimeInterval(7200)

    func message(_ result: LoadResult, login: String = "mira-builds") -> String? {
        let prefs = Preferences(defaults: scratchDefaults())
        prefs.favorites = [login]
        let m = AppModel(loader: ProfileLoader(client: GitHubClient(transport: FakeTransport()), cache: tempCache(),
                                               tokens: MemoryTokenStore()), prefs: prefs, reloadWidgets: {})
        m.setResult(result, for: login)
        return m.offlineMessage(for: login, now: later)
    }

    var saved: ProfileSnapshot {
        ProfileSnapshot(profile: GitHubProfile(login: "mira-builds", name: nil, avatarURL: nil),
                        calendar: calendar(ending: "2026-10-26", [1, 2, 3]), overview: .off, fetchedAt: Self.fetched)
    }

    @Test func estimatedCounts() {
        #expect(message(LoadResult(snapshot: saved, error: .countsUnreadable, estimated: true))
                == "GitHub changed its page, daily counts may be off.")
    }

    @Test func unreadableCountsWithSavedData() {
        #expect(message(LoadResult(snapshot: saved, error: .countsUnreadable))
                == "GitHub changed its page, daily counts may be off. Showing saved data from 2 hr ago.")
    }

    @Test func pageLayoutChangedIsNotCalledOffline() {
        #expect(message(LoadResult(snapshot: saved, error: .markupChanged))
                == "GitHub changed its page, showing data from 2 hr ago.")
    }

    @Test func deletedAccountIsNotCalledOffline() {
        #expect(message(LoadResult(snapshot: saved, error: .userNotFound("mira-builds")))
                == "GitHub has no user named @mira-builds anymore. Showing saved data from 2 hr ago.")
    }

    @Test func realOutagesKeepTheirWording() {
        #expect(message(LoadResult(snapshot: saved, error: .offline)) == "Offline, showing data from 2 hr ago.")
        #expect(message(LoadResult(snapshot: saved, error: .rateLimited(until: later)))
                == "Paused by GitHub, showing data from 2 hr ago.")
    }

    @Test func deletedAccountEndToEnd() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let clock = Clock(Self.fetched)
        let prefs = Preferences(defaults: scratchDefaults())
        prefs.favorites = ["garoknows"]
        let m = AppModel(loader: ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: tempCache(),
                                               tokens: MemoryTokenStore(), now: { clock.now }),
                         prefs: prefs, reloadWidgets: {})
        await m.refresh("garoknows")
        clock.advance(7200)
        t.on("/users/garoknows/contributions", .init(status: 404, body: "Not Found"))
        await m.refresh("garoknows")
        #expect(m.results["garoknows"]?.snapshot?.calendar.total == 93)
        #expect(m.offlineMessage(for: "garoknows", now: clock.now)
                == "GitHub has no user named @garoknows anymore. Showing saved data from 2 hr ago.")
    }
}
