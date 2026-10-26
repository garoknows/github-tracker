import Foundation

/// Everything that can go wrong, phrased as what happened and what to do next.
public enum TrackerError: Error, Equatable, Sendable, LocalizedError {
    case userNotFound(String)
    case rateLimited(until: Date)
    case offline
    case invalidToken
    case server(status: Int)
    case markupChanged
    case blockedHost(String)

    public var errorDescription: String? {
        switch self {
        case .userNotFound(let login):
            return "No GitHub user named '\(login)'. Check the spelling."
        case .rateLimited(let until):
            let minutes = max(1, Int(until.timeIntervalSinceNow / 60))
            return "GitHub asked us to slow down. Trying again in about \(minutes) min."
        case .offline:
            return "Can't reach GitHub. Check your internet connection; showing saved data if there is any."
        case .invalidToken:
            return "GitHub didn't accept that token. Make a new one and paste it in Settings."
        case .server(let status):
            return "GitHub returned an error (\(status)). Try Refresh in a few minutes."
        case .markupChanged:
            return "GitHub changed its page layout. Add a token in Settings as a workaround, and check for an app update."
        case .blockedHost(let host):
            return "Blocked a request to \(host). Tracker for GitHub only talks to GitHub."
        }
    }
}

/// The network seam. Tests swap in a fake; the app uses `URLSession`.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TrackerError.server(status: -1) }
        return (data, http)
    }
}

/// Talks to github.com (HTML) and api.github.com (REST and GraphQL). Nothing else.
public actor GitHubClient {
    public static let userAgent = "TrackerForGitHub/1.0 (+https://github.com/garoknows/github-tracker)"
    /// Hosts the client may contact. Avatars are loaded separately by the UI from GitHub's image host.
    public static let allowedHosts: Set<String> = ["github.com", "api.github.com"]

    private let transport: HTTPTransport
    private let now: @Sendable () -> Date
    /// Per-host "don't call before" times after GitHub says slow down.
    private var blockedUntil: [String: Date] = [:]
    private var consecutiveLimits: [String: Int] = [:]

    public init(transport: HTTPTransport = URLSessionTransport(), now: @escaping @Sendable () -> Date = Date.init) {
        self.transport = transport
        self.now = now
    }

    // MARK: Public HTML (no login)

    public func calendarHTML(for login: String) async throws -> String {
        return try await text(try url("https://github.com/users/\(login)/contributions"), notFound: login)
    }

    public func overviewHTML(for login: String) async throws -> String {
        guard var c = URLComponents(url: try url("https://github.com/\(login)"), resolvingAgainstBaseURL: false) else {
            throw TrackerError.blockedHost(login)
        }
        c.queryItems = [
            .init(name: "action", value: "show"),
            .init(name: "controller", value: "profiles"),
            .init(name: "tab", value: "contributions"),
            .init(name: "user_id", value: login)
        ]
        // Without this header GitHub returns a variant that omits the overview data.
        return try await text(c.url!, headers: ["X-Requested-With": "XMLHttpRequest"], notFound: login)
    }

    // MARK: REST

    public func profile(for login: String, token: String?) async throws -> GitHubProfile {
        let endpoint = try url("https://api.github.com/users/\(login)")
        var headers = ["Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"]
        if let token { headers["Authorization"] = "Bearer \(token)" }
        let data = try await request(endpoint, headers: headers, notFound: login)
        struct User: Decodable {
            let login: String
            let name: String?
            let avatar_url: URL?
            let html_url: URL?
        }
        let u = try JSONDecoder().decode(User.self, from: data)
        return GitHubProfile(login: u.login, name: u.name, avatarURL: u.avatar_url, htmlURL: u.html_url)
    }

    // MARK: GraphQL (token required)

    public struct GraphQLResult: Sendable {
        public let calendar: ContributionCalendar
        public let overview: ActivityOverview
        public let profile: GitHubProfile
    }

    public func graphQL(for login: String, token: String) async throws -> GraphQLResult {
        let query = """
        query($login: String!) { user(login: $login) { login name avatarUrl url
          contributionsCollection {
            totalCommitContributions totalIssueContributions
            totalPullRequestContributions totalPullRequestReviewContributions
            contributionCalendar { totalContributions weeks { contributionDays { date contributionCount contributionLevel } } }
          } } }
        """
        let body = try JSONSerialization.data(withJSONObject: ["query": query, "variables": ["login": login]])
        let data = try await request(
            URL(string: "https://api.github.com/graphql")!, method: "POST", body: body,
            headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json"], notFound: login)
        return try GraphQLDecoding.decode(data, login: login)
    }

    /// Checks a token without storing or logging it. Returns the login it belongs to.
    public func testToken(_ token: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["query": "query { viewer { login } }"])
        let data = try await request(
            URL(string: "https://api.github.com/graphql")!, method: "POST", body: body,
            headers: ["Authorization": "Bearer \(token)", "Content-Type": "application/json"], notFound: nil)
        struct R: Decodable { struct D: Decodable { struct V: Decodable { let login: String }; let viewer: V }; let data: D? }
        guard let login = try JSONDecoder().decode(R.self, from: data).data?.viewer.login else { throw TrackerError.invalidToken }
        return login
    }

    // MARK: Plumbing

    /// Builds a URL from a template that already holds a validated username; refuses anything odd.
    private func url(_ string: String) throws -> URL {
        guard let url = URL(string: string), let host = url.host, Self.allowedHosts.contains(host) else {
            throw TrackerError.blockedHost(string)
        }
        return url
    }

    private func text(_ url: URL, headers: [String: String] = [:], notFound: String) async throws -> String {
        let data = try await request(url, headers: headers.merging(["Accept": "text/html"]) { a, _ in a }, notFound: notFound)
        return String(decoding: data, as: UTF8.self)
    }

    private func request(_ url: URL, method: String = "GET", body: Data? = nil,
                         headers: [String: String], notFound: String?) async throws -> Data {
        guard let host = url.host, Self.allowedHosts.contains(host) else {
            throw TrackerError.blockedHost(url.host ?? url.absoluteString)
        }
        if let until = blockedUntil[host], until > now() {
            throw TrackerError.rateLimited(until: until)
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.httpMethod = method
        req.httpBody = body
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(req)
        } catch let error as TrackerError {
            throw error
        } catch {
            throw TrackerError.offline
        }

        switch response.statusCode {
        case 200..<300:
            consecutiveLimits[host] = 0
            return data
        case 404:
            if let notFound { throw TrackerError.userNotFound(notFound) }
            throw TrackerError.server(status: 404)
        case 401:
            throw TrackerError.invalidToken
        case 403, 429:
            if response.statusCode == 429 || isRateLimit(response) {
                let until = backoff(for: host, response: response)
                blockedUntil[host] = until
                throw TrackerError.rateLimited(until: until)
            }
            throw headers["Authorization"] != nil ? TrackerError.invalidToken : TrackerError.server(status: 403)
        default:
            throw TrackerError.server(status: response.statusCode)
        }
    }

    private func isRateLimit(_ r: HTTPURLResponse) -> Bool {
        r.value(forHTTPHeaderField: "x-ratelimit-remaining") == "0" || r.value(forHTTPHeaderField: "retry-after") != nil
    }

    /// Retry-After wins, then the rate-limit reset time, then exponential backoff (1, 2, 4 … 60 min).
    func backoff(for host: String, response: HTTPURLResponse) -> Date {
        let n = (consecutiveLimits[host] ?? 0) + 1
        consecutiveLimits[host] = n
        if let s = response.value(forHTTPHeaderField: "retry-after").flatMap(TimeInterval.init) {
            return now().addingTimeInterval(max(s, 1))
        }
        if let reset = response.value(forHTTPHeaderField: "x-ratelimit-reset").flatMap(TimeInterval.init) {
            return max(Date(timeIntervalSince1970: reset), now().addingTimeInterval(30))
        }
        return now().addingTimeInterval(min(3600, 60 * pow(2, Double(n - 1))))
    }
}

enum GraphQLDecoding {
    static func decode(_ data: Data, login: String) throws -> GitHubClient.GraphQLResult {
        struct Root: Decodable {
            struct Err: Decodable { let type: String? }
            let data: D?
            let errors: [Err]?
        }
        struct D: Decodable { let user: U? }
        struct U: Decodable {
            let login: String
            let name: String?
            let avatarUrl: URL?
            let url: URL?
            let contributionsCollection: CC
        }
        struct CC: Decodable {
            let totalCommitContributions: Int
            let totalIssueContributions: Int
            let totalPullRequestContributions: Int
            let totalPullRequestReviewContributions: Int
            let contributionCalendar: Cal
        }
        struct Cal: Decodable { let totalContributions: Int; let weeks: [W] }
        struct W: Decodable { let contributionDays: [Day] }
        struct Day: Decodable { let date: String; let contributionCount: Int; let contributionLevel: String }

        let root = try JSONDecoder().decode(Root.self, from: data)
        guard let user = root.data?.user else {
            if root.errors?.contains(where: { $0.type == "NOT_FOUND" }) == true { throw TrackerError.userNotFound(login) }
            throw TrackerError.markupChanged
        }
        let levels = ["NONE": 0, "FIRST_QUARTILE": 1, "SECOND_QUARTILE": 2, "THIRD_QUARTILE": 3, "FOURTH_QUARTILE": 4]
        let cc = user.contributionsCollection
        let days = cc.contributionCalendar.weeks.flatMap(\.contributionDays).compactMap { d -> ContributionDay? in
            guard let date = CivilDate(d.date) else { return nil }
            return ContributionDay(date: date, count: d.contributionCount, level: levels[d.contributionLevel] ?? 0)
        }
        return .init(
            calendar: ContributionCalendar(days: days, total: cc.contributionCalendar.totalContributions),
            overview: Quadrant.percentages(
                commits: cc.totalCommitContributions,
                issues: cc.totalIssueContributions,
                pullRequests: cc.totalPullRequestContributions,
                codeReview: cc.totalPullRequestReviewContributions),
            profile: GitHubProfile(login: user.login, name: user.name, avatarURL: user.avatarUrl, htmlURL: user.url))
    }
}
