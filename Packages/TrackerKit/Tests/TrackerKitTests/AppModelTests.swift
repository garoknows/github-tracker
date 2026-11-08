import Foundation
import Testing
@testable import TrackerKit

@MainActor
final class ReloadCounter {
    var count = 0
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
}
