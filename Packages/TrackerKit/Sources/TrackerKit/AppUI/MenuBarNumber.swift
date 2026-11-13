import AppKit

/// The optional number next to the menu bar icon (Settings → Number in menu bar). Off unless chosen.
///
/// It always describes the Primary profile and uses the same "today" as the 7-day strip
/// (`ContributionCalendar.today(forLocal:)`), so it matches the card at any hour.
public enum MenuBarNumber: String, CaseIterable, Identifiable, Sendable {
    case off, today, currentStreak, lastYear

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .off: "Off"
        case .today: "Today"
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
        case .today:
            let today = calendar.today(forLocal: local)
            return calendar.days.last { $0.date == today }?.count ?? 0
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

    /// What VoiceOver reads for the menu bar item, with the full number rather than "12.3k".
    public func accessibilityLabel(value: Int?, locale: Locale = .current) -> String {
        let app = "Tracker for GitHub"
        guard let value else { return app }
        let n = value.formatted(.number.locale(locale))
        switch self {
        case .off: return app
        case .today: return "\(app), \(value == 1 ? "1 contribution" : "\(n) contributions") today"
        case .currentStreak: return "\(app), current streak \(value == 1 ? "1 day" : "\(n) days")"
        case .lastYear: return "\(app), \(value == 1 ? "1 contribution" : "\(n) contributions") in the last year"
        }
    }

    /// The menu bar's own font, with digits all the same width so nothing shifts as the number changes.
    public static func font() -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)
    }
}
