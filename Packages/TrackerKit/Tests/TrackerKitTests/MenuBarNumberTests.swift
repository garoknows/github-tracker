import AppKit
import Foundation
import Testing
@testable import TrackerKit

/// The optional number next to the menu bar icon (Settings → Number in menu bar).
@MainActor
@Suite("Number in menu bar")
struct MenuBarNumberTests {
    let us = Locale(identifier: "en_US")

    /// The viewer's local date at a wall-clock time in a time zone.
    func localDay(_ ymd: String, hour: Int, _ zone: String) -> CivilDate {
        let tz = TimeZone(identifier: zone)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let d = CivilDate(ymd)!
        return CivilDate(cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day, hour: hour))!, in: tz)
    }

    func snapshot(_ cal: ContributionCalendar) -> ProfileSnapshot {
        ProfileSnapshot(profile: GitHubProfile(login: "mira-builds", name: nil, avatarURL: nil), calendar: cal,
                        overview: .off, fetchedAt: Date(timeIntervalSince1970: 1_800_000_000))
    }

    func model(_ t: FakeTransport = FakeTransport(), defaults: UserDefaults = scratchDefaults(), cache: DiskCache = tempCache(),
               clock: Clock = Clock(Date(timeIntervalSince1970: 1_800_000_000))) -> AppModel {
        AppModel(loader: ProfileLoader(client: GitHubClient(transport: t, now: { clock.now }), cache: cache,
                                       tokens: MemoryTokenStore(), now: { clock.now }),
                 prefs: Preferences(defaults: defaults), reloadWidgets: {})
    }

    @Test func offByDefault() {
        #expect(Preferences(defaults: scratchDefaults()).menuBarNumber == .off)
        #expect(model().menuBarNumber == .off)
    }

    @Test func upgradingFrom111KeepsItOff() {
        // Settings exactly as 1.1.1 left them: no menuBarNumber key at all.
        let old = scratchDefaults()
        old.set(["mira-builds"], forKey: "favorites")
        old.set("ocean", forKey: "theme")
        old.set("dark", forKey: "appearance")
        old.set("glyph", forKey: "iconStyle")
        old.set(60, forKey: "interval")
        let m = model(defaults: old)
        #expect(m.menuBarNumber == .off)
        #expect(m.theme == .ocean && m.iconStyle == .glyph && m.interval == .hour)
        // The unsigned-to-signed move copies old settings and still leaves the number off.
        #expect(Preferences.forApp(shared: scratchDefaults(), local: old).menuBarNumber == .off)
    }

    @Test func choiceIsSavedAndRedrawsTheIcon() {
        let defaults = scratchDefaults()
        let m = model(defaults: defaults)
        var redraws = 0
        m.onChange = { redraws += 1 }
        m.menuBarNumber = .currentStreak
        #expect(redraws == 1)
        #expect(Preferences(defaults: defaults).menuBarNumber == .currentStreak)
        #expect(model(defaults: defaults).menuBarNumber == .currentStreak)
    }

    @Test func settingsNames() {
        #expect(MenuBarNumber.allCases.map(\.name) == ["Off", "Last 7 days", "Current streak", "Last year total"])
    }

    @Test func aSavedTodayChoiceBecomesLastSevenDays() {
        // "Today" counted GitHub's newest UTC day, which drops to 0 every afternoon in the Americas.
        let defaults = scratchDefaults()
        defaults.set("today", forKey: "menuBarNumber")
        #expect(Preferences(defaults: defaults).menuBarNumber == .lastSevenDays)
        #expect(model(defaults: defaults).menuBarNumber == .lastSevenDays)
    }

    @Test func lastSevenDaysDoesNotDropToZeroAtSixPMInLasVegas() {
        // 14 contributions this week, none yet on GitHub's new UTC day (which started at 5 pm).
        let today = localDay("2026-10-26", hour: 18, "America/Los_Angeles")
        let snap = snapshot(calendar(ending: "2026-10-27", [0, 2, 1, 1, 3, 1, 6, 0]))
        #expect(MenuBarNumber.lastSevenDays.value(for: snap, today: today) == 14)
        #expect(MenuBarNumber.lastSevenDays.title(for: snap, today: today, locale: us) == "14")
    }

    @Test func matchesTheCardAtSixPMInLasVegas() {
        // 6 pm in Las Vegas on Oct 26 is Oct 27 in UTC: GitHub's last cell (5 contributions) is "today".
        let today = localDay("2026-10-26", hour: 18, "America/Los_Angeles")
        let cal = calendar(ending: "2026-10-27", [0, 2, 1, 1, 3, 1, 1, 5])
        let snap = snapshot(cal)
        let stats = ContributionStats(calendar: cal, today: today)

        let strip = MenuBarIcon.stripDays(cal, today: today)
        #expect(MenuBarNumber.lastSevenDays.value(for: snap, today: today) == strip.map(\.count).reduce(0, +))
        #expect(MenuBarNumber.lastSevenDays.value(for: snap, today: today) == 14)
        #expect(MenuBarNumber.currentStreak.value(for: snap, today: today) == stats.currentStreak.length)
        #expect(MenuBarNumber.currentStreak.value(for: snap, today: today) == 7)
        #expect(MenuBarNumber.lastYear.value(for: snap, today: today) == stats.total)
        #expect(MenuBarNumber.lastYear.value(for: snap, today: today) == cal.total)
    }

    @Test func eachOptionShowsTheRightValue() {
        let today = CivilDate("2026-10-26")!
        let snap = snapshot(calendar(ending: "2026-10-26", [4, 0, 2, 3, 12_340]))
        #expect(MenuBarNumber.off.title(for: snap, today: today, locale: us) == nil)
        #expect(MenuBarNumber.lastSevenDays.title(for: snap, today: today, locale: us) == "12.3k")
        #expect(MenuBarNumber.currentStreak.title(for: snap, today: today, locale: us) == "3")
        #expect(MenuBarNumber.lastYear.title(for: snap, today: today, locale: us) == "12.3k")

        let quiet = snapshot(calendar(ending: "2026-10-26", [1, 1, 0]))
        #expect(MenuBarNumber.lastSevenDays.title(for: quiet, today: today, locale: us) == "2")
        #expect(MenuBarNumber.currentStreak.title(for: quiet, today: today, locale: us) == "2")
        #expect(MenuBarNumber.lastYear.title(for: quiet, today: today, locale: us) == "2")
    }

    @Test func nothingBeforeAnyDataHasLoaded() {
        for option in MenuBarNumber.allCases {
            #expect(option.title(for: nil, today: CivilDate("2026-10-26")!, locale: us) == nil)
            #expect(option.accessibilityLabel(for: nil, today: CivilDate("2026-10-26")!, locale: us) == "Tracker for GitHub")
        }
    }

    @Test func compactAboveNineThousandNineHundredNinetyNine() {
        let cases: [(Int, String)] = [(0, "0"), (7, "7"), (1_234, "1,234"), (9_999, "9,999"), (10_000, "10k"),
                                      (12_345, "12.3k"), (99_999, "99.9k"), (100_000, "100k"), (123_456, "123k"),
                                      (1_234_567, "1.2M")]
        for (n, text) in cases { #expect(MenuBarNumber.compact(n, locale: us) == text, "\(n)") }
    }

    @Test func voiceOverLabels() {
        let today = CivilDate("2026-10-26")!
        let week = snapshot(calendar(ending: "2026-10-26", [0, 2, 1, 1, 3, 1, 1, 5]))
        let one = snapshot(calendar(ending: "2026-10-26", [0, 0, 0, 0, 0, 0, 1]))
        let big = snapshot(calendar(ending: "2026-10-26", [12_340, 0, 5]))
        #expect(MenuBarNumber.lastSevenDays.accessibilityLabel(for: week, today: today, locale: us)
                == "Tracker for GitHub, 14 contributions in the last 7 days")
        #expect(MenuBarNumber.lastSevenDays.accessibilityLabel(for: one, today: today, locale: us)
                == "Tracker for GitHub, 1 contribution in the last 7 days")
        #expect(MenuBarNumber.currentStreak.accessibilityLabel(for: week, today: today, locale: us)
                == "Tracker for GitHub, current streak 7 days, through Oct 26")
        #expect(MenuBarNumber.currentStreak.accessibilityLabel(for: one, today: today, locale: us)
                == "Tracker for GitHub, current streak 1 day, through Oct 26")
        #expect(MenuBarNumber.lastYear.accessibilityLabel(for: big, today: today, locale: us)
                == "Tracker for GitHub, 12,345 contributions in the last year")
        #expect(MenuBarNumber.off.accessibilityLabel(for: week, today: today, locale: us) == "Tracker for GitHub")
    }

    @Test func digitsAllHaveTheSameWidth() {
        let font = MenuBarNumber.font()
        func width(_ s: String) -> CGFloat { NSAttributedString(string: s, attributes: [.font: font]).size().width }
        #expect(width("1111") == width("8888"))
        #expect(width("11.1k") == width("88.8k"))
        #expect(font.pointSize >= 12)
    }

    @Test func offlineKeepsTheLastGoodNumber() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let defaults = scratchDefaults()
        Preferences(defaults: defaults).favorites = ["garoknows"]
        let cache = tempCache()
        let m = model(t, defaults: defaults, cache: cache)
        m.menuBarNumber = .lastYear
        await m.refresh("garoknows")
        let today = CivilDate("2026-10-26")!
        #expect(m.menuBarNumber.title(for: m.primarySnapshot, today: today, locale: us) == "93")

        t.offline = true
        await m.refresh("garoknows")
        #expect(m.results["garoknows"]?.error == .offline)
        #expect(m.menuBarNumber.title(for: m.primarySnapshot, today: today, locale: us) == "93")

        // After a restart while still offline, the saved copy keeps the number.
        let restarted = model(t, defaults: defaults, cache: cache)
        #expect(restarted.menuBarNumber == .lastYear)
        #expect(restarted.menuBarNumber.title(for: restarted.primarySnapshot, today: today, locale: us) == "93")

        // Never loaded and offline: nothing next to the icon.
        let fresh = scratchDefaults()
        Preferences(defaults: fresh).favorites = ["garoknows"]
        let empty = model(t, defaults: fresh)
        await empty.refresh("garoknows")
        #expect(empty.primarySnapshot == nil)
        #expect(MenuBarNumber.lastYear.title(for: empty.primarySnapshot, today: today, locale: us) == nil)
    }
}
