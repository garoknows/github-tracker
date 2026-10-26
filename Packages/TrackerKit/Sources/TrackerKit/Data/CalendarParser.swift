import Foundation

/// Reads GitHub's contribution calendar HTML (`https://github.com/users/{name}/contributions`).
///
/// The endpoint is undocumented, so all knowledge of its markup lives here and is pinned by fixtures:
/// - each day is a `<td class="ContributionCalendar-day" data-date="…" data-level="…" id="…">`
/// - the count for a day is in the `<tool-tip for="<that id>">` text ("5 contributions on October 26th.")
/// - the total is in the `#js-contribution-activity-description` heading.
public enum CalendarParser {
    public enum Failure: Error, Equatable, Sendable {
        /// The HTML had no day cells; GitHub probably changed its markup.
        case noDays
    }

    public static func parse(_ html: String) throws(Failure) -> ContributionCalendar {
        var countsByID: [String: Int] = [:]
        for match in tooltipRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let id = html.substring(match.range(at: 1)),
                  let text = html.substring(match.range(at: 2)) else { continue }
            countsByID[id] = count(fromTooltip: text)
        }

        var days: [ContributionDay] = []
        for match in dayCellRegex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            guard let tag = html.substring(match.range) else { continue }
            guard let dateString = attribute("data-date", in: tag),
                  let date = CivilDate(dateString) else { continue }
            let level = attribute("data-level", in: tag).flatMap(Int.init) ?? 0
            let id = attribute("id", in: tag)
            // Older markup put the count in data-count; fall back to it, then to the level.
            let count = id.flatMap { countsByID[$0] }
                ?? attribute("data-count", in: tag).flatMap(Int.init)
                ?? (level > 0 ? 1 : 0)
            days.append(ContributionDay(date: date, count: count, level: level))
        }

        guard !days.isEmpty else { throw .noDays }
        return ContributionCalendar(days: days, total: heading(in: html))
    }

    /// "No contributions on …" → 0, "1 contribution on …" → 1, "1,234 contributions on …" → 1234.
    static func count(fromTooltip text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("no ") { return 0 }
        let digits = trimmed.prefix { $0.isNumber || $0 == "," }.filter(\.isNumber)
        return Int(digits) ?? 0
    }

    static func heading(in html: String) -> Int? {
        guard let m = headingRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let number = html.substring(m.range(at: 1)) else { return nil }
        return Int(number.filter(\.isNumber))
    }

    static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\s\(NSRegularExpression.escapedPattern(for: name))=\"([^\"]*)\""
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else { return nil }
        return tag.substring(m.range(at: 1))
    }

    private static var dayCellRegex: NSRegularExpression {
        try! NSRegularExpression(pattern: "<td\\b[^>]*\\bContributionCalendar-day\\b[^>]*>")
    }
    private static var tooltipRegex: NSRegularExpression {
        try! NSRegularExpression(pattern: "<tool-tip\\b[^>]*\\sfor=\"([^\"]+)\"[^>]*>([^<]*)</tool-tip>")
    }
    private static var headingRegex: NSRegularExpression {
        try! NSRegularExpression(pattern: "id=\"js-contribution-activity-description\"[^>]*>\\s*([\\d,]+)\\s*contribution")
    }
}

extension String {
    func substring(_ range: NSRange) -> String? {
        guard range.location != NSNotFound, let r = Range(range, in: self) else { return nil }
        return String(self[r])
    }
}
