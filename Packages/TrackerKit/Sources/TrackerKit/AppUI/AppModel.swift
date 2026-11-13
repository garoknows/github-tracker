import AppKit
import Observation
import ServiceManagement
import SwiftUI
import WidgetKit

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
    /// Off unless chosen, so updating from 1.1.1 (which has no such key) changes nothing.
    var menuBarNumber: MenuBarNumber {
        get { defaults.string(forKey: "menuBarNumber").flatMap(MenuBarNumber.init) ?? .off }
        nonmutating set { defaults.set(newValue.rawValue, forKey: "menuBarNumber") }
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
    public var menuBarNumber: MenuBarNumber { didSet { prefs.menuBarNumber = menuBarNumber; onChange?() } }

    public var tokenStatus: String?
    public private(set) var hasToken: Bool

    /// Called when something the menu bar icon depends on changes.
    public var onChange: (() -> Void)?
    /// Called when the popover should close (e.g. after opening a link).
    public var onClose: (() -> Void)?

    let loader: ProfileLoader
    let prefs: Preferences
    /// Tells widgets to redraw (favorites or token changed). Tests pass their own.
    @ObservationIgnored let reloadWidgets: @MainActor () -> Void
    @ObservationIgnored private var timer: Timer?
    /// The load running for each profile, so a second refresh waits for it instead of downloading again.
    @ObservationIgnored private var inFlight: [String: Task<Void, Never>] = [:]
    /// Profiles whose running load started before the token changed, so they load once more after it.
    @ObservationIgnored private var loadAgain: Set<String> = []

    public convenience init(loader: ProfileLoader = ProfileLoader(), prefs: Preferences = .forApp()) {
        self.init(loader: loader, prefs: prefs, reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() })
    }

    init(loader: ProfileLoader, prefs: Preferences, reloadWidgets: @escaping @MainActor () -> Void) {
        self.loader = loader
        self.prefs = prefs
        self.reloadWidgets = reloadWidgets
        favorites = prefs.favorites
        theme = prefs.theme
        appearance = prefs.appearance
        iconStyle = prefs.iconStyle
        interval = prefs.interval
        menuBarNumber = prefs.menuBarNumber
        // The first read after updating from 1.1.0 moves the token where the widget can read it.
        hasToken = loader.tokens.read() != nil
        if hasToken { reloadWidgets() }
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

    /// The note under a card when the last refresh didn't fully work, saying what actually happened.
    /// For example "Offline, showing data from 2 hr ago." Nil when everything is fresh.
    public func offlineMessage(for login: String, now: Date = Date()) -> String? {
        guard let r = results[login], let snap = r.snapshot else { return nil }
        guard let error = r.error else {
            // The graph is fresh but the Activity overview is the last saved one.
            guard r.overviewError != nil, snap.overview.overview != nil else { return nil }
            return "Couldn't refresh the Activity overview, showing the last saved one."
        }
        let age = Format.age(since: snap.fetchedAt, now: now)
        switch error {
        case .rateLimited:
            return "Paused by GitHub, showing data from \(age)."
        case .countsUnreadable:
            return r.estimated ? "GitHub changed its page, daily counts may be off."
                : "GitHub changed its page, daily counts may be off. Showing saved data from \(age)."
        case .markupChanged:
            return "GitHub changed its page, showing data from \(age)."
        case .userNotFound(let gone):
            return "GitHub has no user named @\(gone) anymore. Showing saved data from \(age)."
        default:
            return "Offline, showing data from \(age)."
        }
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
        // One download both checks the name exists and fills the card.
        let result = await loader.load(login)
        if result.snapshot == nil, result.error != .markupChanged {
            // .markupChanged means the person exists but GitHub's page changed: add them and show why.
            return (result.error ?? .offline).errorDescription
        }
        // Added twice while the first add was still loading.
        if let existing = favorites.firstIndex(where: { $0.caseInsensitiveCompare(login) == .orderedSame }) {
            index = existing
            return nil
        }
        favorites.append(login)
        saveFavorites()
        index = favorites.count - 1
        results[login] = result
        onChange?()
        return nil
    }

    public func remove(_ login: String) {
        favorites.removeAll { $0 == login }
        saveFavorites()
        results[login] = nil
        loader.cache.remove(login)
        index = min(index, max(0, favorites.count - 1))
        onChange?()
    }

    public func moveUp(_ login: String) {
        guard let i = favorites.firstIndex(of: login), i > 0 else { return }
        favorites.swapAt(i, i - 1)
        saveFavorites()
        onChange?()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
        onChange?()
    }

    public func makePrimary(_ login: String) {
        guard let i = favorites.firstIndex(of: login) else { return }
        favorites.insert(favorites.remove(at: i), at: 0)
        saveFavorites()
        index = 0
        onChange?()
    }

    private func saveFavorites() {
        prefs.favorites = favorites
        // Widgets set to "Use my app favorites" read the shared list; tell them it changed.
        reloadWidgets()
    }

    // MARK: Refresh

    /// For screenshots and tests: show a result without touching the network.
    func setResult(_ result: LoadResult, for login: String) {
        results[login] = result
    }

    public func refresh(_ login: String) async {
        await refresh(login, afterChange: false)
    }

    /// One load per profile at a time. A refresh asked for while one is running (the timer and the
    /// Refresh button, say) waits for it instead of downloading the same data again. `afterChange` means
    /// the token changed, so a load that was already running is out of date and one more runs after it.
    func refresh(_ login: String, afterChange: Bool) async {
        if let running = inFlight[login] {
            if afterChange { loadAgain.insert(login) }
            await running.value
            return
        }
        refreshing.insert(login)
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            repeat {
                loadAgain.remove(login)
                let result = await loader.load(login)
                // Removed while loading: don't bring it back (the load also re-saved its cache file).
                guard favorites.contains(login) else {
                    loader.cache.remove(login)
                    break
                }
                results[login] = result
                onChange?()
            } while loadAgain.contains(login)
            loadAgain.remove(login)
            refreshing.remove(login)
            inFlight[login] = nil
        }
        inFlight[login] = task
        await task.value
    }

    /// Refreshes favorites one at a time, so GitHub never sees a burst.
    public func refreshAll() async {
        await refreshAll(afterChange: false)
    }

    func refreshAll(afterChange: Bool) async {
        for login in favorites {
            await refresh(login, afterChange: afterChange)
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
            reloadWidgets()
            return
        }
        tokenStatus = "Testing…"
        do {
            let login = try await loader.client.testToken(trimmed)
            try loader.tokens.save(trimmed)
            hasToken = true
            tokenStatus = "Works. Signed in as @\(login). Saved in your Keychain."
            reloadWidgets()
            await refreshAll(afterChange: true)
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
        reloadWidgets()
    }

    // MARK: Appearance

    /// Makes the popover's own background follow the Appearance setting. SwiftUI's preferredColorScheme
    /// only changes the content, and the popover's glass otherwise follows the window it's attached to
    /// (the menu bar), so a Light choice on a Dark Mac drew dark text on dark glass.
    /// Call it again after the popover is shown, when its window exists.
    public func applyAppearance(to popover: NSPopover) {
        let chosen: NSAppearance? = switch appearance {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
        popover.appearance = chosen
        popover.contentViewController?.view.window?.appearance = chosen
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
