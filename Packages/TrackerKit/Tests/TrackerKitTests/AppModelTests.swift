import Foundation
import Testing
@testable import TrackerKit

@MainActor
final class ReloadCounter {
    var count = 0
}

/// Waits (up to 10 s) for something another task is doing, instead of guessing a sleep time.
@MainActor
func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = Date().addingTimeInterval(10)
    while !condition() {
        guard Date() < deadline else {
            Issue.record("Timed out waiting", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(10))
    }
}

@MainActor
@Suite("App model")
struct AppModelTests {
    func model(_ t: FakeTransport, tokens: TokenStore = MemoryTokenStore(), cache: DiskCache = tempCache(),
               favorites: [String] = [], reloads: ReloadCounter) -> AppModel {
        let prefs = Preferences(defaults: scratchDefaults())
        prefs.favorites = favorites
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: cache, tokens: tokens)
        return AppModel(loader: loader, prefs: prefs, reloadWidgets: { reloads.count += 1 })
    }

    @Test func savingOrRemovingATokenTellsWidgetsRightAway() async throws {
        let t = FakeTransport()
        t.on("api.github.com/graphql", .init(body: #"{"data":{"viewer":{"login":"garoknows"}}}"#))
        let reloads = ReloadCounter()
        let m = model(t, reloads: reloads)
        #expect(reloads.count == 0)

        await m.saveAndTestToken("test-token-not-real")
        #expect(m.hasToken)
        #expect(reloads.count == 1)

        m.removeToken()
        #expect(!m.hasToken)
        #expect(reloads.count == 2)

        await m.saveAndTestToken("   ")
        #expect(reloads.count == 3)
    }

    @Test func launchWithATokenTellsWidgetsSoTheyPickItUp() {
        let reloads = ReloadCounter()
        _ = model(FakeTransport(), tokens: MemoryTokenStore("test-token-not-real"), reloads: reloads)
        #expect(reloads.count == 1)
    }

    @Test func removingAFavoriteWhileItLoadsDoesNotBringItBack() async throws {
        let t = FakeTransport()
        t.on("/users/garoknows/contributions", .init(body: try fixture("calendar_active"), delay: 0.3))
        t.on("tab=contributions", .init(body: try fixture("overview_on")))
        let cache = tempCache()
        let reloads = ReloadCounter()
        let m = model(t, cache: cache, favorites: ["garoknows", "octocat"], reloads: reloads)

        let loading = Task { await m.refresh("garoknows") }
        try await Task.sleep(for: .milliseconds(50))
        #expect(m.refreshing.contains("garoknows"))
        m.remove("garoknows")
        await loading.value

        #expect(m.favorites == ["octocat"])
        #expect(m.results["garoknows"] == nil)
        #expect(cache.snapshot(for: "garoknows") == nil)
        #expect(!m.refreshing.contains("garoknows"))
    }

    // MARK: Adding a favorite downloads its graph once

    @Test func addingAFavoriteDownloadsItsGraphOnce() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        let m = model(t, reloads: ReloadCounter())
        #expect(await m.add("garoknows") == nil)
        #expect(m.favorites == ["garoknows"])
        #expect(m.results["garoknows"]?.snapshot?.calendar.total == 93)
        #expect(t.count("/users/garoknows/contributions") == 1)
    }

    @Test func addingAnUnknownNameStillSaysSo() async {
        let t = FakeTransport()
        let m = model(t, reloads: ReloadCounter())
        #expect(await m.add("nobody-zz9") == "No GitHub user named 'nobody-zz9'. Check the spelling.")
        #expect(m.favorites.isEmpty)
        #expect(m.results["nobody-zz9"] == nil)
        #expect(t.count("/users/nobody-zz9/contributions") == 1)
    }

    @Test func addingWhileOfflineStillSaysSo() async {
        let t = FakeTransport()
        t.offline = true
        let m = model(t, reloads: ReloadCounter())
        #expect(await m.add("mira-builds") == TrackerError.offline.errorDescription)
        #expect(m.favorites.isEmpty)
    }

    // MARK: Overlapping refreshes share one download

    @Test func overlappingRefreshesShareOneDownload() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        t.on("/users/garoknows/contributions", .init(body: try fixture("calendar_active"), delay: 1.5))
        let m = model(t, favorites: ["garoknows"], reloads: ReloadCounter())

        // A timer refresh, and a manual Refresh while its download is still running.
        let timer = Task { await m.refreshAll() }
        try await waitUntil { t.count("/users/garoknows/contributions") == 1 }
        let manual = Task { await m.refresh("garoknows") }
        await timer.value
        await manual.value

        #expect(t.count("/users/garoknows/contributions") == 1)
        #expect(t.peakInFlight("/users/garoknows/contributions") == 1)
        #expect(m.results["garoknows"]?.snapshot?.calendar.total == 93)
        #expect(m.refreshing.isEmpty)
    }

    @Test func savingATokenDuringARefreshLoadsOnceMoreAfterIt() async throws {
        let t = FakeTransport()
        try stubbedGaro(t)
        t.on("/users/garoknows/contributions", .init(body: try fixture("calendar_active"), delay: 1.5))
        t.on("api.github.com/graphql", .init(body: #"{"data":{"viewer":{"login":"garoknows"}}}"#))
        let m = model(t, favorites: ["garoknows"], reloads: ReloadCounter())

        let timer = Task { await m.refresh("garoknows") }
        try await waitUntil { t.count("/users/garoknows/contributions") == 1 }
        await m.saveAndTestToken("test-token-not-real")
        await timer.value

        // The load that started before the token can't use it, so one more runs, but only after it.
        #expect(t.count("/users/garoknows/contributions") == 2)
        #expect(t.peakInFlight("/users/garoknows/contributions") == 1)
        #expect(m.refreshing.isEmpty)
    }
}
