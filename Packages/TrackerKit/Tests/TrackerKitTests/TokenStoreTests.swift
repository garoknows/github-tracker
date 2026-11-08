import Foundation
import Security
import Testing
@testable import TrackerKit

/// A pretend Keychain with the two stores macOS has: the older login keychain, and the data
/// protection keychain that needs an access group the app is entitled to.
final class FakeKeychain: KeychainBackend, @unchecked Sendable {
    private let lock = NSLock()
    var legacy: Data?
    var shared: Data?
    /// False for a build macOS won't let use the access group (errSecMissingEntitlement).
    var entitled = true
    /// How many times the old item's secret was asked for. Each one can mean a Keychain prompt.
    private(set) var legacySecretReads = 0
    private(set) var sharedGroups: Set<String> = []

    init(legacy: String? = nil, shared: String? = nil, entitled: Bool = true) {
        self.legacy = legacy.map { Data($0.utf8) }
        self.shared = shared.map { Data($0.utf8) }
        self.entitled = entitled
    }

    private func isShared(_ q: [String: Any]) -> Bool {
        guard q[kSecUseDataProtectionKeychain as String] as? Bool == true else { return false }
        if let g = q[kSecAttrAccessGroup as String] as? String { sharedGroups.insert(g) }
        return true
    }

    func copy(_ q: [String: Any]) -> (OSStatus, Data?) {
        lock.withLock {
            let s = isShared(q)
            if s && !entitled { return (errSecMissingEntitlement, nil) }
            guard let item = s ? shared : legacy else { return (errSecItemNotFound, nil) }
            guard q[kSecReturnData as String] as? Bool == true else { return (errSecSuccess, nil) }
            if !s { legacySecretReads += 1 }
            return (errSecSuccess, item)
        }
    }

    func add(_ a: [String: Any]) -> OSStatus {
        lock.withLock {
            let s = isShared(a)
            if s && !entitled { return errSecMissingEntitlement }
            let data = a[kSecValueData as String] as? Data
            if s { shared = data } else { legacy = data }
            return errSecSuccess
        }
    }

    func update(_ q: [String: Any], _ changes: [String: Any]) -> OSStatus {
        lock.withLock {
            let s = isShared(q)
            if s && !entitled { return errSecMissingEntitlement }
            guard (s ? shared : legacy) != nil else { return errSecItemNotFound }
            let data = changes[kSecValueData as String] as? Data
            if s { shared = data } else { legacy = data }
            return errSecSuccess
        }
    }

    func delete(_ q: [String: Any]) -> OSStatus {
        lock.withLock {
            let s = isShared(q)
            if s && !entitled { return errSecMissingEntitlement }
            guard (s ? shared : legacy) != nil else { return errSecItemNotFound }
            if s { shared = nil } else { legacy = nil }
            return errSecSuccess
        }
    }
}

@Suite("Token in the Keychain")
struct TokenStoreTests {
    static let group = "ABCDE12345.io.github.garoknows.tracker"

    func app(_ k: FakeKeychain, group: String? = Self.group) -> KeychainTokenStore {
        KeychainTokenStore(accessGroup: group, canPrompt: true, backend: k)
    }

    func widget(_ k: FakeKeychain, group: String? = Self.group) -> KeychainTokenStore {
        KeychainTokenStore(accessGroup: group, canPrompt: false, backend: k)
    }

    @Test func upgradeMovesTheOldTokenOnce() {
        let k = FakeKeychain(legacy: "old-token")
        #expect(app(k).lookup() == .found("old-token"))
        #expect(k.shared == Data("old-token".utf8))
        #expect(k.legacy == nil, "the old copy should be deleted after the move")
        #expect(app(k).lookup() == .found("old-token"))
        #expect(k.legacySecretReads == 1, "at most one possible Keychain prompt")
        #expect(k.sharedGroups == [Self.group])
    }

    @Test func widgetBeforeTheMoveSaysOpenTrackerAndNeverPrompts() {
        let k = FakeKeychain(legacy: "old-token")
        #expect(widget(k).lookup() == .unreadable)
        #expect(k.legacySecretReads == 0)
        #expect(k.legacy != nil, "the widget must not delete or move anything")

        // Once the app has run, the widget reads the shared token silently.
        _ = app(k).lookup()
        #expect(widget(k).lookup() == .found("old-token"))
    }

    @Test func signedSaveGoesToTheSharedKeychainOnly() throws {
        let k = FakeKeychain(legacy: "stale")
        try app(k).save("new-token")
        #expect(k.shared == Data("new-token".utf8))
        #expect(k.legacy == nil)
        #expect(widget(k).lookup() == .found("new-token"))
        try app(k).save("newer-token")
        #expect(widget(k).lookup() == .found("newer-token"))
    }

    @Test func deleteRemovesBothCopies() throws {
        let k = FakeKeychain(legacy: "a", shared: "b")
        app(k).delete()
        #expect(k.legacy == nil && k.shared == nil)
        #expect(app(k).lookup() == .none)
        #expect(widget(k).lookup() == .none)
    }

    @Test func unsignedBuildKeepsTheLoginKeychain() throws {
        let k = FakeKeychain()
        try app(k, group: nil).save("tok")
        #expect(k.legacy == Data("tok".utf8))
        #expect(k.shared == nil)
        #expect(k.sharedGroups.isEmpty)
        #expect(app(k, group: nil).lookup() == .found("tok"))
        #expect(widget(k, group: nil).lookup() == .unreadable)
    }

    @Test func missingEntitlementFallsBackWithoutFailing() throws {
        let k = FakeKeychain(entitled: false)
        try app(k).save("tok")
        #expect(k.legacy == Data("tok".utf8))
        #expect(app(k).lookup() == .found("tok"))
        #expect(widget(k).lookup() == .unreadable)
        app(k).delete()
        #expect(app(k).lookup() == .none)
    }

    @Test func nothingSaved() {
        let k = FakeKeychain()
        #expect(app(k).lookup() == .none)
        #expect(widget(k).lookup() == .none)
        #expect(k.legacySecretReads == 0)
    }

    @Test func memoryStore() throws {
        let s = MemoryTokenStore()
        #expect(s.read() == nil)
        try s.save("abc")
        #expect(s.read() == "abc")
        s.delete()
        #expect(s.read() == nil)
        #expect(MemoryTokenStore(unreadable: true).lookup() == .unreadable)
    }
}

@Suite("Widget without a readable token")
struct WidgetTokenTests {
    @Test func saysOpenTrackerInsteadOfAddAToken() async throws {
        let t = FakeTransport()
        t.on("/users/octo/contributions", .init(body: try fixture("calendar_active")))
        t.on("tab=contributions", .init(body: "<div>unexpected</div>"))
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: tempCache(), tokens: MemoryTokenStore(unreadable: true))
        let r = await loader.load("octo")
        #expect(r.snapshot?.overview == .tokenUnreadable)
        #expect(r.snapshot?.overview.placeholderMessage == "Open Tracker to use your token.")
        #expect(!t.requests.contains { $0.value(forHTTPHeaderField: "Authorization") != nil })
    }

    @Test func tokenNeverReachesTheDiskCache() async throws {
        let t = FakeTransport()
        t.on("/users/octo/contributions", .init(body: try fixture("calendar_active")))
        t.on("tab=contributions", .init(body: "<div>unexpected</div>"))
        t.on("api.github.com/graphql", .init(body: """
        {"data":{"user":{"login":"octo","name":null,"avatarUrl":null,"url":"https://github.com/octo","contributionsCollection":{
          "totalCommitContributions":3,"totalIssueContributions":1,"totalPullRequestContributions":0,"totalPullRequestReviewContributions":0,
          "contributionCalendar":{"totalContributions":4,"weeks":[]}}}}}
        """))
        let cache = tempCache()
        let secret = "test-secret-value-never-cache-7f3a9c"
        let loader = ProfileLoader(client: GitHubClient(transport: t), cache: cache, tokens: MemoryTokenStore(secret))
        #expect(await loader.load("octo").snapshot?.overview.overview != nil)
        let files = try FileManager.default.contentsOfDirectory(at: cache.directory, includingPropertiesForKeys: nil)
        #expect(!files.isEmpty)
        for f in files {
            #expect(!(try String(contentsOf: f, encoding: .utf8)).contains(secret))
        }
    }
}
