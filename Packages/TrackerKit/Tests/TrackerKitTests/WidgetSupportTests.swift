import Foundation
import Testing
@testable import TrackerKit

/// A throwaway UserDefaults suite, so tests never touch real preferences.
func scratchDefaults() -> UserDefaults {
    let name = "TrackerKitTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Suite("Widget follows the app's favorites")
struct WidgetProfilesTests {
    let typed: [String?] = ["octocat", nil, "  @Mira-Builds ", "OCTOCAT", "not a name", "https://github.com/torvalds"]

    @Test func usesAppFavoritesWhenChosenAndShared() {
        let logins = WidgetProfiles.logins(useAppFavorites: true, appFavorites: ["garoknows", "mira-builds"], typed: typed)
        #expect(logins == ["garoknows", "mira-builds"])
    }

    @Test func fallsBackToTypedNamesWhenNothingIsShared() {
        // Unsigned builds have no App Group, so the shared list is empty.
        let logins = WidgetProfiles.logins(useAppFavorites: true, appFavorites: [], typed: typed)
        #expect(logins == ["octocat", "Mira-Builds", "torvalds"])
    }

    @Test func typedNamesWinWhenTheToggleIsOff() {
        let logins = WidgetProfiles.logins(useAppFavorites: false, appFavorites: ["garoknows"], typed: typed)
        #expect(logins == ["octocat", "Mira-Builds", "torvalds"])
    }

    @Test func nothingConfigured() {
        #expect(WidgetProfiles.logins(useAppFavorites: true, appFavorites: [], typed: [nil, nil, nil, nil, nil]).isEmpty)
    }
}

@Suite("Widget paging")
struct WidgetPageTests {
    @Test func startsAtFirstAndWrapsBothWays() {
        let d = scratchDefaults()
        #expect(WidgetPage.index(for: "a,b,c", count: 3, defaults: d) == 0)
        WidgetPage.shift("a,b,c", by: 1, count: 3, defaults: d)
        #expect(WidgetPage.index(for: "a,b,c", count: 3, defaults: d) == 1)
        WidgetPage.shift("a,b,c", by: 1, count: 3, defaults: d)
        WidgetPage.shift("a,b,c", by: 1, count: 3, defaults: d)
        #expect(WidgetPage.index(for: "a,b,c", count: 3, defaults: d) == 0)
        WidgetPage.shift("a,b,c", by: -1, count: 3, defaults: d)
        #expect(WidgetPage.index(for: "a,b,c", count: 3, defaults: d) == 2)
    }

    @Test func eachConfigurationHasItsOwnPage() {
        let d = scratchDefaults()
        WidgetPage.shift("a,b", by: 1, count: 2, defaults: d)
        #expect(WidgetPage.index(for: "a,b", count: 2, defaults: d) == 1)
        #expect(WidgetPage.index(for: "x,y", count: 2, defaults: d) == 0)
    }

    @Test func staysInRangeWhenTheListShrinks() {
        let d = scratchDefaults()
        d.set(4, forKey: "page.k")
        #expect(WidgetPage.index(for: "k", count: 3, defaults: d) == 1)
        d.set(-7, forKey: "page.k")
        #expect(WidgetPage.index(for: "k", count: 3, defaults: d) == 2)
    }

    @Test func emptyListIsSafe() {
        let d = scratchDefaults()
        #expect(WidgetPage.index(for: "", count: 0, defaults: d) == 0)
        WidgetPage.shift("", by: 1, count: 0, defaults: d)
        #expect(d.object(forKey: "page.") == nil)
    }
}

@Suite("Moving preferences into the App Group")
struct PreferencesMigrationTests {
    @Test func copiesOldUnsignedSettingsTheFirstTime() {
        let local = scratchDefaults(), shared = scratchDefaults()
        local.set(["garoknows", "octocat"], forKey: "favorites")
        local.set("ocean", forKey: "theme")
        local.set("dark", forKey: "appearance")
        local.set("glyph", forKey: "iconStyle")
        local.set(60, forKey: "interval")

        let prefs = Preferences.forApp(shared: shared, local: local)
        #expect(prefs.favorites == ["garoknows", "octocat"])
        #expect(prefs.theme == .ocean)
        #expect(prefs.appearance == .dark)
        #expect(prefs.iconStyle == .glyph)
        #expect(prefs.interval == .hour)
        // Written to the shared group, so the widget sees the same list.
        #expect(shared.stringArray(forKey: "favorites") == ["garoknows", "octocat"])
    }

    @Test func neverOverwritesTheSharedListLater() {
        let local = scratchDefaults(), shared = scratchDefaults()
        shared.set(["mira-builds"], forKey: "favorites")
        local.set(["stale-old-list"], forKey: "favorites")
        local.set("halloween", forKey: "theme")
        let prefs = Preferences.forApp(shared: shared, local: local)
        #expect(prefs.favorites == ["mira-builds"])
        #expect(prefs.theme == .green)
    }

    @Test func emptySharedFavoritesStillCountAsMigrated() {
        // Someone who removed every favorite in a signed build must not get the old unsigned list back.
        let local = scratchDefaults(), shared = scratchDefaults()
        shared.set([String](), forKey: "favorites")
        local.set(["stale-old-list"], forKey: "favorites")
        #expect(Preferences.forApp(shared: shared, local: local).favorites.isEmpty)
    }

    @Test func withoutAGroupUsesTheAppsOwnDefaults() {
        let local = scratchDefaults()
        local.set(["garoknows"], forKey: "favorites")
        let prefs = Preferences.forApp(shared: nil, local: local)
        #expect(prefs.favorites == ["garoknows"])
        prefs.favorites = ["octocat"]
        #expect(local.stringArray(forKey: "favorites") == ["octocat"])
    }
}
