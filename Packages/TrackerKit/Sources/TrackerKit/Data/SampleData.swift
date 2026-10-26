import Foundation

/// Fictional, deterministic data for the widget gallery preview and SwiftUI previews.
public enum SampleData {
    public static func snapshot(login: String = "octo-sample", name: String = "Sample profile",
                                today: CivilDate = CivilDate(Date()), seed: UInt64 = 7) -> ProfileSnapshot {
        var rng = SplitMix(seed: seed)
        let start = today.adding(days: -364)
        let first = start.adding(days: -start.weekday)
        var days: [ContributionDay] = []
        var d = first
        while d <= today {
            let ago = d.days(until: today)
            let chance = ago <= 20 ? 0.7 : (ago > 175 && ago < 215 ? 0.15 : 0.04)
            let count = rng.next() < chance ? 1 + Int(rng.next() * 7) : 0
            let level = count == 0 ? 0 : min(4, 1 + count / 2)
            days.append(ContributionDay(date: d, count: count, level: level))
            d = d.adding(days: 1)
        }
        return ProfileSnapshot(
            profile: GitHubProfile(login: login, name: name, avatarURL: nil),
            calendar: ContributionCalendar(days: days),
            overview: .available(ActivityOverview(commits: 49, issues: 43, pullRequests: 8, codeReview: 0), source: .publicProfile),
            fetchedAt: Date().addingTimeInterval(-240))
    }

    struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
        }
    }
}
