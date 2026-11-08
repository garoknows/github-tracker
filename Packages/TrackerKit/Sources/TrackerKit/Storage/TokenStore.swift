import Foundation
import Security

/// What a token lookup found.
public enum TokenLookup: Equatable, Sendable {
    case none
    case found(String)
    /// A token is saved, but this process can't read it without a prompt it isn't allowed to show
    /// (the widget, before the app has moved the token to the shared keychain, or in unsigned builds).
    case unreadable

    public var token: String? {
        if case .found(let t) = self { return t }
        return nil
    }
}

/// Where the optional GitHub token lives. The app uses the Keychain; tests use memory.
public protocol TokenStore: Sendable {
    func lookup() -> TokenLookup
    func save(_ token: String) throws
    func delete()
}

extension TokenStore {
    public func read() -> String? { lookup().token }
}

/// Stores the token only in the macOS Keychain. It is never logged or written to disk or UserDefaults.
///
/// Signed builds keep it in the data protection keychain, in the App Group's access group
/// (`<TeamID>.io.github.garoknows.tracker`), so the app and its widget can both read it without a prompt.
/// Version 1.1.0 and earlier kept it in the older login keychain, where only the app that saved it can
/// read it silently; the app moves it over the first time it reads it.
///
/// Unsigned (ad-hoc) builds have no App Group. There, or if macOS refuses the access group
/// (`errSecMissingEntitlement`), the token stays in the login keychain as before.
public struct KeychainTokenStore: TokenStore {
    public static let service = "io.github.garoknows.tracker"
    let service: String
    let account: String
    let accessGroup: String?
    let canPrompt: Bool
    let backend: KeychainBackend

    /// - Parameters:
    ///   - accessGroup: the shared keychain access group; nil means the login keychain only.
    ///   - canPrompt: true for the app, which may show one Keychain prompt while moving an old token.
    ///     The widget passes false: it can't show prompts, so it never asks for the old item's secret.
    public init(service: String = KeychainTokenStore.service, account: String = "github-token",
                accessGroup: String? = AppGroup.identifier, canPrompt: Bool = true) {
        self.init(service: service, account: account, accessGroup: accessGroup, canPrompt: canPrompt, backend: SystemKeychain())
    }

    init(service: String = KeychainTokenStore.service, account: String = "github-token",
         accessGroup: String?, canPrompt: Bool, backend: KeychainBackend) {
        self.service = service
        self.account = account
        self.accessGroup = accessGroup
        self.canPrompt = canPrompt
        self.backend = backend
    }

    public struct KeychainError: Error, LocalizedError {
        public let status: OSStatus
        public var errorDescription: String? {
            "Couldn't save the token in your Keychain (error \(status)). Try again, or restart the app."
        }
    }

    /// The login keychain item used by 1.1.0 and earlier, and by unsigned builds.
    var legacyQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    /// The shared item in the data protection keychain, or nil without an access group.
    var sharedQuery: [String: Any]? {
        guard let accessGroup else { return nil }
        var q = legacyQuery
        q[kSecUseDataProtectionKeychain as String] = true
        q[kSecAttrAccessGroup as String] = accessGroup
        return q
    }

    public func lookup() -> TokenLookup {
        if let shared = sharedQuery {
            let (status, token) = readSecret(shared)
            switch status {
            case errSecSuccess:
                if let token { return .found(token) }
                return .none
            case errSecMissingEntitlement:
                break // This build can't use the access group; behave like an unsigned build.
            default:
                // Nothing shared yet. A token saved by an older version is moved over by the app.
                if canPrompt, let old = readSecret(legacyQuery).1 {
                    if upsert(old, shared) == errSecSuccess { _ = backend.delete(legacyQuery) }
                    return .found(old)
                }
                return legacyExists() ? .unreadable : .none
            }
        }
        if canPrompt { return readSecret(legacyQuery).1.map(TokenLookup.found) ?? .none }
        return legacyExists() ? .unreadable : .none
    }

    public func save(_ token: String) throws {
        if let shared = sharedQuery {
            let status = upsert(token, shared)
            if status == errSecSuccess {
                _ = backend.delete(legacyQuery)
                return
            }
            guard status == errSecMissingEntitlement else { throw KeychainError(status: status) }
        }
        let status = upsert(token, legacyQuery)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() {
        if let shared = sharedQuery { _ = backend.delete(shared) }
        _ = backend.delete(legacyQuery)
    }

    private func readSecret(_ base: [String: Any]) -> (OSStatus, String?) {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        let (status, data) = backend.copy(q)
        guard status == errSecSuccess, let data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            return (status, nil)
        }
        return (status, token)
    }

    /// Whether the old item exists, asking only for its attributes, which never needs a prompt.
    private func legacyExists() -> Bool {
        var q = legacyQuery
        q[kSecReturnAttributes as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        return backend.copy(q).0 == errSecSuccess
    }

    private func upsert(_ token: String, _ base: [String: Any]) -> OSStatus {
        let data = Data(token.utf8)
        var status = backend.update(base, [kSecValueData as String: data])
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecAttrLabel as String] = "Tracker for GitHub token"
            status = backend.add(add)
        }
        return status
    }
}

/// The four Keychain calls, so tests can check the migration logic without touching a real keychain.
protocol KeychainBackend: Sendable {
    /// Returns the status and, when asked for with `kSecReturnData`, the secret.
    func copy(_ query: [String: Any]) -> (OSStatus, Data?)
    func add(_ attributes: [String: Any]) -> OSStatus
    func update(_ query: [String: Any], _ changes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

struct SystemKeychain: KeychainBackend {
    func copy(_ query: [String: Any]) -> (OSStatus, Data?) {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return (status, item as? Data)
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func update(_ query: [String: Any], _ changes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, changes as CFDictionary)
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory store for tests and previews.
public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?
    private let unreadable: Bool

    public init(_ value: String? = nil) {
        self.value = value
        self.unreadable = false
    }

    /// A store that says a token exists but can't be read here, like the widget before migration.
    public init(unreadable: Bool) {
        self.value = nil
        self.unreadable = unreadable
    }

    public func lookup() -> TokenLookup {
        lock.withLock {
            if let value { return .found(value) }
            return unreadable ? .unreadable : .none
        }
    }

    public func save(_ token: String) throws { lock.withLock { value = token } }
    public func delete() { lock.withLock { value = nil } }
}
