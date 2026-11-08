import Foundation

/// Which people a widget shows. Lives here (not in the widget target) so it can be tested.
public enum WidgetProfiles {
    /// The app's favorites when chosen and available, otherwise the usernames typed in Edit Widget.
    public static func logins(useAppFavorites: Bool, appFavorites: [String], typed: [String?]) -> [String] {
        if useAppFavorites, !appFavorites.isEmpty { return appFavorites }
        return typedLogins(typed)
    }

    /// Valid, de-duplicated usernames in the order typed.
    public static func typedLogins(_ typed: [String?]) -> [String] {
        var seen = Set<String>()
        return typed.compactMap { raw in
            guard let raw, let login = try? Username.normalize(raw), seen.insert(login.lowercased()).inserted else { return nil }
            return login
        }
    }
}

/// Remembers which person each widget configuration is showing (the ◀ ▶ buttons).
public enum WidgetPage {
    public static func index(for key: String, count: Int, defaults: UserDefaults = .standard) -> Int {
        guard count > 0 else { return 0 }
        let stored = defaults.integer(forKey: "page.\(key)")
        return ((stored % count) + count) % count
    }

    public static func shift(_ key: String, by delta: Int, count: Int, defaults: UserDefaults = .standard) {
        guard count > 0 else { return }
        let next = ((index(for: key, count: count, defaults: defaults) + delta) % count + count) % count
        defaults.set(next, forKey: "page.\(key)")
    }
}
