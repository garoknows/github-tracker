import Foundation

/// Reads the Activity overview percentages from the public profile's contributions fragment
/// (`https://github.com/{name}?action=show&controller=profiles&tab=contributions&user_id={name}`).
///
/// GitHub renders `data-percentages="{"Commits":53,"Issues":40,…}"` on
/// `.js-activity-overview-graph-container` only when the owner has Activity overview turned on.
public enum OverviewParser {
    public static func parse(_ html: String) -> OverviewState {
        guard let m = percentagesRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let raw = html.substring(m.range(at: 1)) else {
            // A real contributions fragment without the overview box means the owner turned it off.
            // Anything else (box without data, unexpected markup) is unknown, so offer the token path.
            let isFragment = html.contains("js-yearly-contributions") || html.contains("graph-before-activity-overview")
            return isFragment && !html.contains("activity-overview-box") ? .off : .needsToken
        }
        let json = raw
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .needsToken
        }
        func value(_ key: String) -> Int {
            let match = dict.first { $0.key.caseInsensitiveCompare(key) == .orderedSame }?.value
            return (match as? NSNumber)?.intValue ?? 0
        }
        let overview = ActivityOverview(
            commits: value("Commits"),
            issues: value("Issues"),
            pullRequests: value("Pull requests"),
            codeReview: value("Code review"))
        return .available(overview, source: .publicProfile)
    }

    private static var percentagesRegex: NSRegularExpression {
        try! NSRegularExpression(pattern: "data-percentages=\"([^\"]*)\"")
    }
}

public enum Quadrant {
    /// Converts raw GraphQL totals into whole-number percentages that add up to 100
    /// (largest-remainder rounding), or all zeros when there's no activity.
    public static func percentages(commits: Int, issues: Int, pullRequests: Int, codeReview: Int) -> ActivityOverview {
        let values = [commits, issues, pullRequests, codeReview].map { max(0, $0) }
        let total = values.reduce(0, +)
        guard total > 0 else { return ActivityOverview(commits: 0, issues: 0, pullRequests: 0, codeReview: 0) }

        let exact = values.map { Double($0) * 100 / Double(total) }
        var rounded = exact.map { Int($0.rounded(.down)) }
        let leftover = 100 - rounded.reduce(0, +)
        let order = exact.indices.sorted { (exact[$0] - Double(rounded[$0])) > (exact[$1] - Double(rounded[$1])) }
        for i in order.prefix(leftover) { rounded[i] += 1 }
        return ActivityOverview(commits: rounded[0], issues: rounded[1], pullRequests: rounded[2], codeReview: rounded[3])
    }
}
