import Foundation
import Testing
@testable import TrackerKit

func fixture(_ name: String) throws -> String {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures"))
    return try String(contentsOf: url, encoding: .utf8)
}

@Suite("Calendar parser")
struct CalendarParserTests {
    @Test func activeUser() throws {
        let cal = try CalendarParser.parse(try fixture("calendar_active"))
        #expect(cal.days.count == 366)
        #expect(cal.total == 93)
        #expect(cal.days.reduce(0) { $0 + $1.count } == 93)
        #expect(cal.days.first?.date == CivilDate("2025-10-26"))
        #expect(cal.days.last?.date == CivilDate("2026-10-26"))
        // Oldest first, one entry per day, no gaps.
        for (a, b) in zip(cal.days, cal.days.dropFirst()) { #expect(a.date.adding(days: 1) == b.date) }
        let oct21 = try #require(cal.days.first { $0.date == CivilDate("2026-10-21") })
        #expect(oct21.count == 21)
        #expect(oct21.level > 0)
    }

    @Test func heavyUserWithThousandsSeparator() throws {
        let cal = try CalendarParser.parse(try fixture("calendar_heavy"))
        #expect(cal.total == 3945)
        #expect(cal.days.count >= 365)
        #expect(cal.days.contains { $0.level == 4 })
    }

    @Test func emptyUser() throws {
        let cal = try CalendarParser.parse(try fixture("calendar_empty"))
        #expect(cal.total == 0)
        #expect(cal.days.allSatisfy { $0.count == 0 && $0.level == 0 })
    }

    @Test func notFoundBodyHasNoDays() throws {
        #expect(throws: CalendarParser.Failure.noDays) { try CalendarParser.parse(try fixture("calendar_notfound")) }
        #expect(throws: CalendarParser.Failure.noDays) { try CalendarParser.parse("<html>totally different</html>") }
    }

    @Test func tooltipCounts() {
        #expect(CalendarParser.count(fromTooltip: "No contributions on October 26th.") == 0)
        #expect(CalendarParser.count(fromTooltip: "1 contribution on April 2nd.") == 1)
        #expect(CalendarParser.count(fromTooltip: " 1,234 contributions on May 5th.") == 1234)
    }

    @Test func attributeOrderDoesNotMatter() throws {
        let html = """
        <h2 id="js-contribution-activity-description" class="f4">\n 3\n contributions in the last year</h2>
        <td data-level="2" class="ContributionCalendar-day" id="d1" data-date="2024-02-29"></td>
        <tool-tip for="d1" class="sr-only">3 contributions on February 29th.</tool-tip>
        """
        let cal = try CalendarParser.parse(html)
        #expect(cal.days == [ContributionDay(date: CivilDate(year: 2024, month: 2, day: 29), count: 3, level: 2)])
        #expect(cal.total == 3)
    }

    @Test func lastWeeksStartsOnSunday() throws {
        let cal = try CalendarParser.parse(try fixture("calendar_active"))
        let twelve = cal.lastWeeks(12)
        #expect(twelve.first?.date.weekday == 0)
        #expect(twelve.count <= 12 * 7 && twelve.count > 11 * 7)
        #expect(twelve.last == cal.days.last)
    }
}

@Suite("Activity overview parser")
struct OverviewParserTests {
    @Test func publicOverviewOn() throws {
        let state = OverviewParser.parse(try fixture("overview_on"))
        #expect(state == .available(ActivityOverview(commits: 53, issues: 40, pullRequests: 7, codeReview: 0), source: .publicProfile))
    }

    @Test func commitsOnly() throws {
        let o = try #require(OverviewParser.parse(try fixture("overview_commits_only")).overview)
        #expect(o == ActivityOverview(commits: 100, issues: 0, pullRequests: 0, codeReview: 0))
    }

    @Test func ownerTurnedItOff() throws {
        #expect(OverviewParser.parse(try fixture("overview_off")) == .off)
    }

    @Test func unknownMarkupAsksForToken() {
        #expect(OverviewParser.parse("<html>login wall</html>") == .needsToken)
        #expect(OverviewParser.parse("<div class=\"activity-overview-box\"></div>") == .needsToken)
    }

    @Test func placeholderMessages() {
        #expect(OverviewState.off.placeholderMessage == "Activity overview is turned off on this profile.")
        #expect(OverviewState.needsToken.placeholderMessage == "Add a free token in Settings to show this chart.")
    }
}

@Suite("Quadrant percentages")
struct QuadrantTests {
    @Test func allZeros() {
        let o = Quadrant.percentages(commits: 0, issues: 0, pullRequests: 0, codeReview: 0)
        #expect(o.isEmpty)
    }

    @Test func oneCategory() {
        #expect(Quadrant.percentages(commits: 7, issues: 0, pullRequests: 0, codeReview: 0)
                == ActivityOverview(commits: 100, issues: 0, pullRequests: 0, codeReview: 0))
        #expect(Quadrant.percentages(commits: 0, issues: 0, pullRequests: 0, codeReview: 3).codeReview == 100)
    }

    @Test func sumsToOneHundred() {
        for (a, b, c, d) in [(1, 1, 1, 0), (2, 1, 1, 1), (53, 40, 7, 0), (1, 2, 3, 4), (999, 1, 1, 1)] {
            let o = Quadrant.percentages(commits: a, issues: b, pullRequests: c, codeReview: d)
            #expect(o.commits + o.issues + o.pullRequests + o.codeReview == 100)
        }
        let thirds = Quadrant.percentages(commits: 1, issues: 1, pullRequests: 1, codeReview: 0)
        #expect([thirds.commits, thirds.issues, thirds.pullRequests].sorted() == [33, 33, 34])
    }

    @Test func negativeIgnored() {
        #expect(Quadrant.percentages(commits: -5, issues: 5, pullRequests: 0, codeReview: 0).issues == 100)
    }
}

@Suite("GraphQL decoding")
struct GraphQLTests {
    @Test func decodesCalendarAndTotals() throws {
        let json = """
        {"data":{"user":{"login":"octo","name":"Octo Cat","avatarUrl":"https://avatars.githubusercontent.com/u/1","url":"https://github.com/octo",
          "contributionsCollection":{"totalCommitContributions":6,"totalIssueContributions":2,"totalPullRequestContributions":2,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":10,"weeks":[{"contributionDays":[
            {"date":"2026-10-25","contributionCount":0,"contributionLevel":"NONE"},
            {"date":"2026-10-26","contributionCount":10,"contributionLevel":"FOURTH_QUARTILE"}]}]}}}}}
        """
        let r = try GraphQLDecoding.decode(Data(json.utf8), login: "octo")
        #expect(r.calendar.total == 10)
        #expect(r.calendar.days.last?.level == 4)
        #expect(r.overview == ActivityOverview(commits: 60, issues: 20, pullRequests: 20, codeReview: 0))
        #expect(r.profile.displayName == "Octo Cat")
    }

    @Test func notFound() {
        let json = #"{"data":{"user":null},"errors":[{"type":"NOT_FOUND","message":"Could not resolve"}]}"#
        #expect(throws: TrackerError.userNotFound("ghost")) { try GraphQLDecoding.decode(Data(json.utf8), login: "ghost") }
    }
}
