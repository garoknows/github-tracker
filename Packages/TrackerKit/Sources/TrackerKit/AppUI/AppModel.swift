import AppKit
import Observation
import ServiceManagement
import SwiftUI

public enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case strip, glyph
    public var id: String { rawValue }
    public var name: String { self == .strip ? "7-day strip" : "Simple icon" }
}

public enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case fifteen = 15, thirty = 30, hour = 60, threeHours = 180
    public var id: Int { rawValue }
    public var name: String {
        switch self {
        case .fifteen: "15 minutes"
        case .thirty: "30 minutes"
        case .hour: "1 hour"
        case .threeHours: "3 hours"
        }
    }
}

/// Small, non-secret preferences. The token is never stored here.
public struct Preferences {
    let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var favorites: [String] {
        get { defaults.stringArray(forKey: "favorites") ?? [] }
        nonmutating set { defaults.set(newValue, forKey: "favorites") }
    }
    var theme: ColorTheme {
        get { defaults.string(forKey: "theme").flatMap(ColorTheme.init) ?? .green }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "theme") }
    }
    var appearance: Appearance {
        get { defaults.string(forKey: "appearance").flatMap(Appearance.init) ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "appearance") }
    }
    var iconStyle: MenuBarIconStyle {
        get { defaults.string(forKey: "iconStyle").flatMap(MenuBarIconStyle.init) ?? .strip }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "iconStyle") }
    }
    var interval: RefreshInterval {
        get { RefreshInterval(rawValue: defaults.integer(forKey: "interval")) ?? .thirty }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "interval") }
    }
}

/// Everything the menu bar app shows and does. The first favorite is the Primary one.
@MainActor @Observable
public final class AppModel {
    public static let maxFavorites = 10
    public static let repoURL = URL(string: "https://github.com/garoknows/github-tracker")!

    public enum Screen: Equatable { case cards, settings }

    public private(set) var favorites: [String]
    public private(set) var results: [String: LoadResult] = [:]
    public private(set) var refreshing: Set<String> = []
    public var index = 0
    public var screen: Screen = .cards

    public var theme: ColorTheme { didSet { prefs.theme = theme; onChange?() } }
    public var appearance: Appearance { didSet { prefs.appearance = appearance; onChange?() } }
    public var iconStyle: MenuBarIconStyle { didSet { prefs.iconStyle = iconStyle; onChange?() } }
    public var interval: RefreshInterval { didSet { prefs.interval = interval; scheduleRefresh() } }

    public var tokenStatus: String?
    public private(set) var hasToken: Bool

    /// Called when something the menu bar icon depends on changes.
    public var onChange: (() -> Void)?
    /// Called when the popover should close (e.g. after opening a link).
    public var onClose: (() -> Void)?

    let loader: ProfileLoader
    let prefs: Preferences
    @ObservationIgnored private var timer: Timer?

    public init(loader: ProfileLoader = ProfileLoader(), prefs: Preferences = Preferences()) {
        self.loader = loader
        self.prefs = prefs
        favorites = prefs.favorites
        theme = prefs.theme
        appearance = prefs.appearance
        iconStyle = prefs.iconStyle
        interval = prefs.interval
        hasToken = loader.tokens.read() != nil
        for login in favorites {
            if let cached = loader.cache.snapshot(for: login) {
                results[login] = LoadResult(snapshot: cached, error: nil)
            }
        }
    }

    // MARK: Current card

    public var primary: String? { favorites.first }
    public var current: String? { favorites.indices.contains(index) ? favorites[index] : nil }
    public var currentResult: LoadResult? { current.flatMap { results[$0] } }
    public var primarySnapshot: ProfileSnapshot? { primary.flatMap { results[$0]?.snapshot } }

    public func next() { if !favorites.isEmpty { index = (index + 1) % favorites.count } }
    public func previous() { if !favorites.isEmpty { index = (index - 1 + favorites.count) % favorites.count } }

    /// "Offline, showing data from 2 hr ago." when the last refresh failed but we have saved data.
    public func offlineMessage(for login: String, now: Date = Date()) -> String? {
        guard let r = results[login], let error = r.error, let snap = r.snapshot else { return nil }
        if case .rateLimited = error { return "Paused by GitHub, showing data from \(Format.age(since: snap.fetchedAt, now: now))." }
        return "Offline, showing data from \(Format.age(since: snap.fetchedAt, now: now))."
    }

    // MARK: Favorites

    /// Validates and adds a profile. Returns an error message to show, or nil on success.
    public func add(_ input: String) async -> String? {
        let login: String
        do { login = try Username.normalize(input) } catch { return error.errorDescription }
        if let existing = favorites.firstIndex(where: { $0.caseInsensitiveCompare(login) == .orderedSame }) {
            index = existing
            return "@\(favorites[existing]) is already in your favorites."
        }
        guard favorites.count < Self.maxFavorites else {
            return "You can keep up to \(Self.maxFavorites) favorites. Remove one in Settings first."
        }
        do {
            try await loader.validate(login)
        } catch let e as TrackerError {
            return e.errorDescription
        } catch {
            return TrackerError.offline.errorDescription
        }
        favorites.append(login)
        prefs.favorites = favorites
        index = favorites.count - 1
        await refresh(login)
        return nil
    }

    public func remove(_ login: String) {
        favorites.removeAll { $0 == login }
        prefs.favorites = favorites
        results[login] = nil
        loader.cache.remove(login)
        index = min(index, max(0, favorites.count - 1))
        onChange?()
    }

    public func moveUp(_ login: String) {
        guard let i = favorites.firstIndex(of: login), i > 0 else { return }
        favorites.swapAt(i, i - 1)
        prefs.favorites = favorites
        onChange?()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        prefs.favorites = favorites
        onChange?()
    }

    public func makePrimary(_ login: String) {
        guard let i = favorites.firstIndex(of: login) else { return }
        favorites.insert(favorites.remove(at: i), at: 0)
        prefs.favorites = favorites
        index = 0
        onChange?()
    }

    // MARK: Refresh

    /// For screenshots and tests: show a result without touching the network.
    func setResult(_ result: LoadResult, for login: String) {
        results[login] = result
    }

    public func refresh(_ login: String) async {
        refreshing.insert(login)
        let result = await loader.load(login)
        results[login] = result
        refreshing.remove(login)
        onChange?()
    }

    /// Refreshes favorites one at a time, so GitHub never sees a burst.
    public func refreshAll() async {
        for login in favorites {
            await refresh(login)
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    public func refreshCurrent() async {
        if let current { await refresh(current) }
    }

    public func start() {
        scheduleRefresh()
        Task { await refreshAll() }
    }

    private func scheduleRefresh() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval.rawValue * 60), repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
    }

    // MARK: Token

    public func saveAndTestToken(_ token: String) async {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loader.tokens.delete()
            hasToken = false
            tokenStatus = "Token removed."
            return
        }
        tokenStatus = "Testing…"
        do {
            let login = try await loader.client.testToken(trimmed)
            try loader.tokens.save(trimmed)
            hasToken = true
            tokenStatus = "Works. Signed in as @\(login). Saved in your Keychain."
            await refreshAll()
        } catch let e as TrackerError {
            tokenStatus = e.errorDescription
        } catch {
            tokenStatus = error.localizedDescription
        }
    }

    public func removeToken() {
        loader.tokens.delete()
        hasToken = false
        tokenStatus = "Token removed from your Keychain."
    }

    // MARK: Launch at login

    public private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    public private(set) var launchAtLoginError: String?

    public func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "macOS didn't allow that. Check System Settings → General → Login Items."
        }
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        if on && status == .requiresApproval {
            launchAtLoginError = "Approve Tracker for GitHub in System Settings → General → Login Items."
        }
    }

    // MARK: Links

    public func open(_ url: URL) {
        NSWorkspace.shared.open(url)
        onClose?()
    }

    public func openCurrentProfile() {
        if let current { open(URL(string: "https://github.com/\(current)")!) }
    }

    public func checkForUpdates() {
        open(Self.repoURL.appendingPathComponent("releases/latest"))
    }

    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }
}
