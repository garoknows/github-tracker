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

    @Test func ignoresDaysMoreThanOneDayAhead() {
        // GitHub is at most one day ahead of any viewer, so anything later is not real data.
        let cal = calendar(ending: "2026-10-28", [1, 1, 5, 9])
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

/// Without a login, GitHub groups contributions by UTC date. These pin that every number agrees with
/// GitHub's own heading total, whatever the viewer's time zone and clock say.
@Suite("UTC day boundary")
struct UTCBoundaryTests {
    /// The viewer's local date at a wall-clock time in a time zone.
    func localDay(_ ymd: String, hour: Int, _ zone: String) -> CivilDate {
        let tz = TimeZone(identifier: zone)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = CivilDate(ymd)!
        let instant = cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: hour))!
        return CivilDate(instant, in: tz)
    }

    func expectAgrees(_ cal: ContributionCalendar, today: CivilDate, streak: Int, endsYesterday: Bool,
                      sourceLocation: SourceLocation = #_sourceLocation) {
        let s = ContributionStats(calendar: cal, today: today)
        #expect(s.total == cal.total, "Total tile disagrees with the heading", sourceLocation: sourceLocation)
        #expect(s.currentStreak.length == streak, sourceLocation: sourceLocation)
        #expect(s.currentStreakEndsYesterday == endsYesterday, sourceLocation: sourceLocation)
        let strip = MenuBarIcon.stripDays(cal, today: today)
        #expect(strip.last == cal.days.last, "Menu bar strip dropped GitHub's last day", sourceLocation: sourceLocation)
        #expect(strip.count == min(7, cal.days.count), sourceLocation: sourceLocation)
    }

    @Test func lasVegasEveningSeesTomorrowsUTCCell() {
        // 6 pm in Las Vegas on Oct 26 is already Oct 27 in UTC, so GitHub's last cell is "tomorrow".
        let today = localDay("2026-10-26", hour: 18, "America/Los_Angeles")
        #expect(today == CivilDate("2026-10-26"))
        let cal = calendar(ending: "2026-10-27", [0, 2, 1, 1, 3, 1, 1, 5])
        expectAgrees(cal, today: today, streak: 7, endsYesterday: false)
        let s = ContributionStats(calendar: cal, today: today)
        #expect(s.bestDay?.count == 5)
        #expect(s.currentStreak.end == CivilDate("2026-10-27"))
    }

    @Test func viewerAheadOfUTC() {
        // 5 am Oct 27 in Tokyo is still Oct 26 in UTC: GitHub's last cell is the viewer's "yesterday".
        let today = localDay("2026-10-27", hour: 5, "Asia/Tokyo")
        #expect(today == CivilDate("2026-10-27"))
        let cal = calendar(ending: "2026-10-26", [0, 1, 1, 4])
        expectAgrees(cal, today: today, streak: 3, endsYesterday: true)
    }

    @Test func daylightSavingChangeDays() {
        // Clocks fall back in Las Vegas on Nov 1, 2026: 6 pm PST is 2 am UTC on Nov 2.
        let fallBack = localDay("2026-11-01", hour: 18, "America/Los_Angeles")
        #expect(fallBack == CivilDate("2026-11-01"))
        expectAgrees(calendar(ending: "2026-11-02", [0, 1, 1, 1, 1, 1, 1, 2]), today: fallBack, streak: 7, endsYesterday: false)

        // Clocks spring forward on Mar 8, 2026: 6 pm PDT is 1 am UTC on Mar 9.
        let springForward = localDay("2026-03-08", hour: 18, "America/Los_Angeles")
        #expect(springForward == CivilDate("2026-03-08"))
        expectAgrees(calendar(ending: "2026-03-09", [3, 0, 0, 0, 0, 0, 1, 1]), today: springForward, streak: 2, endsYesterday: false)
    }

    @Test func morningInLasVegasMatchesUTC() {
        // Before 5 pm the dates match; nothing changes.
        let today = localDay("2026-10-26", hour: 9, "America/Los_Angeles")
        expectAgrees(calendar(ending: "2026-10-26", [0, 1, 1, 1, 1, 1, 1, 1]), today: today, streak: 7, endsYesterday: false)
    }
}
