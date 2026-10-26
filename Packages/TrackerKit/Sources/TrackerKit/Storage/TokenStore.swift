import Foundation
import Security

/// Where the optional GitHub token lives. The app uses the Keychain; tests use memory.
public protocol TokenStore: Sendable {
    func read() -> String?
    func save(_ token: String) throws
    func delete()
}

/// Stores the token only in the macOS Keychain. It is never logged or written to disk or UserDefaults.
public struct KeychainTokenStore: TokenStore {
    public static let service = "io.github.garoknows.tracker"
    let service: String
    let account: String

    public init(service: String = KeychainTokenStore.service, account: String = "github-token") {
        self.service = service
        self.account = account
    }

    public struct KeychainError: Error, LocalizedError {
        public let status: OSStatus
        public var errorDescription: String? {
            "Couldn't save the token in your Keychain (error \(status)). Try again, or restart the app."
        }
    }

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    public func read() -> String? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    public func save(_ token: String) throws {
        let data = Data(token.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            add[kSecAttrLabel as String] = "Tracker for GitHub token"
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() {
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory store for tests and previews.
public final class MemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    public init(_ value: String? = nil) {
        self.value = value
    }

    public func read() -> String? { lock.withLock { value } }
    public func save(_ token: String) throws { lock.withLock { value = token } }
    public func delete() { lock.withLock { value = nil } }
}
