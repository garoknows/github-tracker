import AppKit

/// The optional number next to the menu bar icon (Settings → Number in menu bar). Off unless chosen.
///
/// It always describes the Primary profile and uses the same days as the 7-day strip
/// (`ContributionCalendar.today(forLocal:)`), so it matches the card at any hour.
public enum MenuBarNumber: String, CaseIterable, Identifiable, Sendable {
    case off, lastSevenDays, currentStreak, lastYear

    /// Reads a saved choice. 1.2.0 test builds had "today" (GitHub's newest UTC day, which drops to 0
    /// every afternoon in the Americas); it becomes Last 7 days.
    public init?(saved: String) {
        self.init(rawValue: saved == "today" ? MenuBarNumber.lastSevenDays.rawValue : saved)
    }

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .off: "Off"
        case .lastSevenDays: "Last 7 days"
        case .currentStreak: "Current streak"
        case .lastYear: "Last year total"
        }
    }

    /// The number for this profile, or nil when it's off or nothing has ever loaded.
    /// Offline, the snapshot is the last saved one, so the last good number stays.
    public func value(for snapshot: ProfileSnapshot?, today local: CivilDate) -> Int? {
        guard let calendar = snapshot?.calendar else { return nil }
        switch self {
        case .off:
            return nil
        case .lastSevenDays:
            return MenuBarIcon.stripDays(calendar, today: local).reduce(0) { $0 + $1.count }
        case .currentStreak:
            return ContributionStats(calendar: calendar, today: local).currentStreak.length
        case .lastYear:
            return ContributionStats(calendar: calendar, today: local).total
        }
    }

    /// The text next to the icon, or nil for none.
    public func title(for snapshot: ProfileSnapshot?, today: CivilDate, locale: Locale = .current) -> String? {
        value(for: snapshot, today: today).map { Self.compact($0, locale: locale) }
    }

    /// "9,999", then "10k", "12.3k", "123k", "1.2M": short enough for the menu bar.
    /// Rounds down, so the menu bar never shows more than the real number.
    public static func compact(_ n: Int, locale: Locale = .current) -> String {
        if n < 10_000 { return n.formatted(.number.locale(locale)) }
        let (value, suffix): (Double, String) = n < 1_000_000 ? (Double(n) / 1_000, "k") : (Double(n) / 1_000_000, "M")
        let shown = value < 100 ? (value * 10).rounded(.down) / 10 : value.rounded(.down)
        return shown.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(locale)) + suffix
    }

    /// What VoiceOver reads for the menu bar item, with the full number rather than "12.3k", and the
    /// streak's GitHub date ("current streak 7 days, through Oct 27").
    public func accessibilityLabel(for snapshot: ProfileSnapshot?, today: CivilDate, locale: Locale = .current) -> String {
        let app = "Tracker for GitHub"
        guard let calendar = snapshot?.calendar, let value = value(for: snapshot, today: today) else { return app }
        let n = value.formatted(.number.locale(locale))
        let contributions = value == 1 ? "1 contribution" : "\(n) contributions"
        switch self {
        case .off:
            return app
        case .lastSevenDays:
            return "\(app), \(contributions) in the last 7 days"
        case .currentStreak:
            let streak = ContributionStats(calendar: calendar, today: today).currentStreak
            let days = "current streak \(value == 1 ? "1 day" : "\(n) days")"
            return streak.through.map { "\(app), \(days), \($0)" } ?? "\(app), \(days)"
        case .lastYear:
            return "\(app), \(contributions) in the last year"
        }
    }

    /// The menu bar's own font, with digits all the same width so nothing shifts as the number changes.
    public static func font() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
    }
}
