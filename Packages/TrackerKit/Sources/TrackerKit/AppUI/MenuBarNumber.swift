import AppKit

/// The optional number next to the menu bar icon. STUB: filled in after the tests fail.
public enum MenuBarNumber: String, CaseIterable, Identifiable, Sendable {
    case off, today, currentStreak, lastYear
    public var id: String { rawValue }
    public var name: String { "" }

    /// The value for the Primary profile, using the same "today" as the 7-day strip.
    public func value(for snapshot: ProfileSnapshot?, today: CivilDate) -> Int? { nil }

    /// "9,999", then "10k", "12.3k", "1.2M": short enough for the menu bar.
    public static func compact(_ n: Int, locale: Locale = .current) -> String { "" }

    /// What VoiceOver reads for the menu bar item.
    public func accessibilityLabel(value: Int?, locale: Locale = .current) -> String { "" }

    /// The text next to the icon, or nil for none.
    public func title(for snapshot: ProfileSnapshot?, today: CivilDate, locale: Locale = .current) -> String? { nil }

    /// Digits all the same width, so the menu bar doesn't shift as the number changes.
    public static func font() -> NSFont { NSFont.systemFont(ofSize: NSFont.systemFontSize) }
}
