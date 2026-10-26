import Foundation

/// The five numbers in the stats row, computed locally from daily counts.
public struct ContributionStats: Hashable, Sendable {
    public struct Streak: Hashable, Sendable {
        public let length: Int
        public let start: CivilDate?
        public let end: CivilDate?

        public static let none = Streak(length: 0, start: nil, end: nil)
    }

    public let total: Int
    public let bestDay: ContributionDay?
    public let averagePerDay: Double
    public let currentStreak: Streak
    public let longestStreak: Streak
    /// True when today has no contributions yet but yesterday did, so the current streak is still alive.
    public let currentStreakEndsYesterday: Bool

    /// - Parameters:
    ///   - today: the viewer's local date. Days after it (GitHub can be a time zone ahead) are ignored.
    public init(calendar: ContributionCalendar, today: CivilDate) {
        let days = calendar.days.filter { $0.date <= today }
        total = days.reduce(0) { $0 + $1.count }

        var best: ContributionDay?
        for day in days where day.count > (best?.count ?? 0) { best = day }
        bestDay = best

        averagePerDay = days.isEmpty ? 0 : Double(total) / Double(days.count)

        // Longest run of consecutive calendar days with at least one contribution.
        var longest = Streak.none
        var runStart: CivilDate?
        var runLength = 0
        var previous: CivilDate?
        for day in days {
            let contiguous = previous.map { $0.adding(days: 1) == day.date } ?? true
            if day.count > 0 {
                if runLength > 0 && contiguous {
                    runLength += 1
                } else {
                    runLength = 1
                    runStart = day.date
                }
                if runLength > longest.length {
                    longest = Streak(length: runLength, start: runStart, end: day.date)
                }
            } else {
                runLength = 0
            }
            previous = day.date
        }
        longestStreak = longest

        // Current streak: counts back from today, or from yesterday if today is still empty.
        let byDate = Dictionary(days.map { ($0.date, $0.count) }, uniquingKeysWith: max)
        var cursor = today
        var skippedToday = false
        if (byDate[cursor] ?? 0) == 0 {
            cursor = cursor.adding(days: -1)
            skippedToday = true
        }
        var length = 0
        var start: CivilDate?
        while (byDate[cursor] ?? 0) > 0 {
            length += 1
            start = cursor
            cursor = cursor.adding(days: -1)
        }
        let end = skippedToday ? today.adding(days: -1) : today
        currentStreak = length > 0 ? Streak(length: length, start: start, end: end) : .none
        currentStreakEndsYesterday = length > 0 && skippedToday
    }
}

public enum Format {
    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    /// "Oct 21"
    public static func short(_ d: CivilDate) -> String { "\(monthNames[d.month - 1]) \(d.day)" }

    /// "Oct 21, 2026"
    public static func long(_ d: CivilDate) -> String { "\(short(d)), \(d.year)" }

    public static func monthName(_ month: Int) -> String { monthNames[month - 1] }

    /// "7 contributions on Oct 21, 2026" / "No contributions on …"
    public static func tooltip(_ day: ContributionDay) -> String {
        "\(contributions(day.count)) on \(long(day.date))"
    }

    public static func contributions(_ n: Int) -> String {
        switch n {
        case 0: return "No contributions"
        case 1: return "1 contribution"
        default: return "\(n.formatted()) contributions"
        }
    }

    public static func days(_ n: Int) -> String { n == 1 ? "1 day" : "\(n) days" }

    /// "Updated just now", "Updated 4 min ago", "Updated 2 hr ago", "Updated 3 days ago"
    public static func age(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86_400: return "\(Int(seconds / 3600)) hr ago"
        default:
            let d = Int(seconds / 86_400)
            return d == 1 ? "1 day ago" : "\(d) days ago"
        }
    }
}
