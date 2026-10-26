import Foundation
import Testing
@testable import TrackerKit

/// Builds a calendar ending on `end` from counts, oldest first.
func calendar(ending end: String, _ counts: [Int]) -> ContributionCalendar {
    let last = CivilDate(end)!
    let days = counts.enumerated().map { i, c in
        ContributionDay(date: last.adding(days: i - counts.count + 1), count: c, level: c > 0 ? 1 : 0)
    }
    return ContributionCalendar(days: days)
}

@Suite("Civil dates")
struct CivilDateTests {
    @Test func parsing() {
        #expect(CivilDate("2024-02-29") != nil)
        #expect(CivilDate("2023-02-29") == nil)
        #expect(CivilDate("2026-13-01") == nil)
        #expect(CivilDate("nope") == nil)
        #expect(CivilDate("2026-10-21")?.description == "2026-10-21")
    }

    @Test func arithmeticAcrossLeapDayAndYearEnd() {
        #expect(CivilDate("2024-02-28")!.adding(days: 1) == CivilDate("2024-02-29"))
        #expect(CivilDate("2024-02-29")!.adding(days: 1) == CivilDate("2024-03-01"))
        #expect(CivilDate("2025-12-31")!.adding(days: 1) == CivilDate("2026-01-01"))
        #expect(CivilDate("2026-01-01")!.adding(days: -1) == CivilDate("2025-12-31"))
        #expect(CivilDate("2024-01-01")!.days(until: CivilDate("2025-01-01")!) == 366)
        for n in [-800_000, -1, 0, 1, 19_000, 20_388] {
            #expect(CivilDate(dayNumber: n).dayNumber == n)
        }
    }

    @Test func weekdays() {
        #expect(CivilDate("1970-01-01")!.weekday == 4) // Thursday
        #expect(CivilDate("2026-10-25")!.weekday == 0) // Sunday
        #expect(CivilDate("2026-10-26")!.weekday == 1) // Monday
    }

    @Test func timeZonesPickTheLocalDay() {
        // 2026-10-26 03:00 UTC is still Oct 25 in Los Angeles and already Oct 26 in Tokyo.
        let instant = Date(timeIntervalSince1970: 1_792_983_600)
        #expect(CivilDate(instant, in: TimeZone(identifier: "UTC")!) == CivilDate("2026-10-26"))
        #expect(CivilDate(instant, in: TimeZone(identifier: "America/Los_Angeles")!) == CivilDate("2026-10-25"))
        #expect(CivilDate(instant, in: TimeZone(identifier: "Asia/Tokyo")!) == CivilDate("2026-10-26"))
    }
}

@Suite("Stats")
struct StatsTests {
    @Test func basics() {
        let cal = calendar(ending: "2026-10-26", [0, 3, 0, 7, 2, 0, 1])
        let s = ContributionStats(calendar: cal, today: CivilDate("2026-10-26")!)
        #expect(s.total == 13)
        #expect(s.bestDay?.count == 7)
        #expect(s.bestDay?.date == CivilDate("2026-10-23"))
        #expect(abs(s.averagePerDay - 13.0 / 7.0) < 0.0001)
        #expect(s.longestStreak.length == 2)
        #expect(s.longestStreak.start == CivilDate("2026-10-23"))
        #expect(s.longestStreak.end == CivilDate("2026-10-24"))
        #expect(s.currentStreak.length == 1)
        #expect(!s.currentStreakEndsYesterday)
    }

    @Test func todayWithNoContributionsKeepsStreakAlive() {
        let cal = calendar(ending: "2026-10-26", [0, 1, 1, 1, 0])
        let s = ContributionStats(calendar: cal, today: CivilDate("2026-10-26")!)
        #expect(s.currentStreak.length == 3)
        #expect(s.currentStreak.end == CivilDate("2026-10-25"))
        #expect(s.currentStreakEndsYesterday)
    }

    @Test func twoEmptyDaysBreaksStreak() {
        let cal = calendar(ending: "2026-10-26", [1, 1, 0, 0])
        let s = ContributionStats(calendar: cal, today: CivilDate("2026-10-26")!)
        #expect(s.currentStreak == .none)
        #expect(s.longestStreak.length == 2)
    }

    @Test func streakAcrossYearBoundaryAndLeapDay() {
        let newYear = calendar(ending: "2026-01-02", [0, 1, 1, 1, 1])
        let s = ContributionStats(calendar: newYear, today: CivilDate("2026-01-02")!)
        #expect(s.currentStreak.length == 4)
        #expect(s.currentStreak.start == CivilDate("2025-12-30"))

        let leap = calendar(ending: "2024-03-01", [1, 1, 1])
        let l = ContributionStats(calendar: leap, today: CivilDate("2024-03-01")!)
        #expect(l.longestStreak.start == CivilDate("2024-02-28"))
        #expect(l.longestStreak.length == 3)
    }

    @Test func ignoresDaysAfterToday() {
        // GitHub can already show "tomorrow" for viewers west of UTC.
        let cal = calendar(ending: "2026-10-27", [1, 1, 5])
        let s = ContributionStats(calendar: cal, today: CivilDate("2026-10-26")!)
        #expect(s.total == 2)
        #expect(s.bestDay?.count == 1)
        #expect(s.currentStreak.length == 2)
    }

    @Test func gapInDataBreaksLongestStreak() {
        let a = ContributionDay(date: CivilDate("2026-10-01")!, count: 1, level: 1)
        let b = ContributionDay(date: CivilDate("2026-10-03")!, count: 1, level: 1)
        let s = ContributionStats(calendar: ContributionCalendar(days: [a, b]), today: CivilDate("2026-10-03")!)
        #expect(s.longestStreak.length == 1)
    }

    @Test func emptyCalendar() {
        let s = ContributionStats(calendar: ContributionCalendar(days: []), today: CivilDate("2026-10-26")!)
        #expect(s.total == 0 && s.bestDay == nil && s.averagePerDay == 0)
        #expect(s.currentStreak == .none && s.longestStreak == .none)
    }

    @Test func realFixtureNumbers() throws {
        let cal = try CalendarParser.parse(try fixture("calendar_active"))
        let s = ContributionStats(calendar: cal, today: CivilDate("2026-10-26")!)
        #expect(s.total == cal.total)
        #expect(s.bestDay?.count == 36)
        #expect(s.currentStreak.length >= 1)
    }
}

@Suite("Formatting")
struct FormatTests {
    @Test func strings() {
        let day = ContributionDay(date: CivilDate("2026-10-21")!, count: 7, level: 3)
        #expect(Format.tooltip(day) == "7 contributions on Oct 21, 2026")
        #expect(Format.contributions(0) == "No contributions")
        #expect(Format.contributions(1) == "1 contribution")
        #expect(Format.days(1) == "1 day")
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(Format.age(since: now, now: now) == "just now")
        #expect(Format.age(since: now.addingTimeInterval(-240), now: now) == "4 min ago")
        #expect(Format.age(since: now.addingTimeInterval(-7200), now: now) == "2 hr ago")
        #expect(Format.age(since: now.addingTimeInterval(-86_400 * 3), now: now) == "3 days ago")
    }
}

@Suite("Usernames")
struct UsernameTests {
    @Test(arguments: [
        ("garoknows", "garoknows"),
        ("@garoknows", "garoknows"),
        ("  @garoknows \n", "garoknows"),
        ("https://github.com/garoknows", "garoknows"),
        ("http://www.github.com/garoknows/", "garoknows"),
        ("github.com/garoknows?tab=repositories", "garoknows"),
        ("https://github.com/garoknows/github-tracker", "garoknows"),
        ("https://github.com/users/garoknows/contributions", "garoknows"),
        ("Mira-Builds", "Mira-Builds")
    ])
    func normalizes(input: String, expected: String) throws {
        #expect(try Username.normalize(input) == expected)
    }

    @Test(arguments: ["-bad", "bad-", "do--uble", "has space", "émile", String(repeating: "a", count: 40), "https://gitlab.com/x"])
    func rejects(input: String) {
        #expect(throws: Username.Problem.self) { try Username.normalize(input) }
    }

    @Test func emptyHasFriendlyMessage() {
        #expect(throws: Username.Problem.empty) { try Username.normalize("   ") }
        #expect(Username.Problem.empty.errorDescription == "Type a GitHub username, like garoknows.")
    }
}
