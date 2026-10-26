import Foundation

/// One square in the contribution graph.
public struct ContributionDay: Hashable, Codable, Sendable {
    public let date: CivilDate
    public let count: Int
    /// GitHub's 0...4 intensity level for this day.
    public let level: Int

    public init(date: CivilDate, count: Int, level: Int) {
        self.date = date
        self.count = count
        self.level = max(0, min(4, level))
    }
}

/// A year of contribution days, oldest first.
public struct ContributionCalendar: Hashable, Codable, Sendable {
    public let days: [ContributionDay]
    /// The total GitHub prints in its heading ("93 contributions in the last year").
    public let total: Int

    public init(days: [ContributionDay], total: Int? = nil) {
        self.days = days.sorted { $0.date < $1.date }
        self.total = total ?? days.reduce(0) { $0 + $1.count }
    }

    /// The most recent `weeks` columns, starting on a Sunday like GitHub's graph.
    public func lastWeeks(_ weeks: Int) -> [ContributionDay] {
        guard let last = days.last?.date else { return [] }
        let start = last.adding(days: -last.weekday - (weeks - 1) * 7)
        return days.filter { $0.date >= start }
    }
}

/// The four percentages in GitHub's "Activity overview" chart.
public struct ActivityOverview: Hashable, Codable, Sendable {
    public let commits: Int
    public let issues: Int
    public let pullRequests: Int
    public let codeReview: Int

    public init(commits: Int, issues: Int, pullRequests: Int, codeReview: Int) {
        self.commits = commits
        self.issues = issues
        self.pullRequests = pullRequests
        self.codeReview = codeReview
    }

    public var isEmpty: Bool { commits + issues + pullRequests + codeReview == 0 }
}

/// Whether the quadrant chart can be shown, and if not, why.
public enum OverviewState: Hashable, Codable, Sendable {
    case available(ActivityOverview, source: OverviewSource)
    /// The profile owner turned Activity overview off.
    case off
    /// The public page didn't include it; a token would unlock the GraphQL path.
    case needsToken

    public var overview: ActivityOverview? {
        if case .available(let o, _) = self { return o }
        return nil
    }

    public var placeholderMessage: String? {
        switch self {
        case .available: return nil
        case .off: return "Activity overview is turned off on this profile."
        case .needsToken: return "Add a free token in Settings to show this chart."
        }
    }
}

public enum OverviewSource: String, Hashable, Codable, Sendable {
    /// Read from the public profile page, exactly as GitHub shows it.
    case publicProfile
    /// Computed locally from GraphQL totals (public contributions only).
    case graphQL
}

/// Name and avatar from the REST API.
public struct GitHubProfile: Hashable, Codable, Sendable {
    public let login: String
    public let name: String?
    public let avatarURL: URL?
    public let htmlURL: URL

    public init(login: String, name: String?, avatarURL: URL?, htmlURL: URL? = nil) {
        self.login = login
        self.name = name
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL ?? URL(string: "https://github.com/\(login)")!
    }

    public var displayName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return login
    }

    /// One or two letters for the avatar placeholder.
    public var initials: String {
        let words = displayName.split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
        let letters = words.prefix(2).compactMap { $0.first }
        return String(letters.isEmpty ? Array(login.prefix(1)) : letters).uppercased()
    }
}

/// Everything a card needs for one person, plus when it was fetched.
public struct ProfileSnapshot: Hashable, Codable, Sendable {
    public let profile: GitHubProfile
    public let calendar: ContributionCalendar
    public let overview: OverviewState
    public let fetchedAt: Date

    public init(profile: GitHubProfile, calendar: ContributionCalendar, overview: OverviewState, fetchedAt: Date) {
        self.profile = profile
        self.calendar = calendar
        self.overview = overview
        self.fetchedAt = fetchedAt
    }

    public var login: String { profile.login }
    public var profileURL: URL { profile.htmlURL }
}
