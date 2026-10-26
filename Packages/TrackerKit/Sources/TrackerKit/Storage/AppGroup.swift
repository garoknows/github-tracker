import Foundation

/// The App Group shared by the app and its widget. Only signed builds have one: the group name comes
/// from the `TrackerAppGroup` Info.plist key, which is empty in ad-hoc (unsigned) builds.
public enum AppGroup {
    public static var identifier: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "TrackerAppGroup") as? String,
              !id.isEmpty, !id.hasPrefix("$(") else { return nil }
        return id
    }

    /// Shared preferences, or nil when there is no usable group (unsigned build, or not entitled).
    public static var defaults: UserDefaults? {
        guard let id = identifier,
              FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil else { return nil }
        return UserDefaults(suiteName: id)
    }

    /// The app's favorites, as the widget sees them. Empty when nothing is shared.
    public static func sharedFavorites() -> [String] {
        defaults?.stringArray(forKey: Preferences.favoritesKey) ?? []
    }
}

extension Preferences {
    static let favoritesKey = "favorites"

    /// Preferences for the app: the shared App Group when signed, otherwise this app's own defaults.
    /// The first time a group is available, favorites saved by an older unsigned build move over.
    public static func forApp() -> Preferences {
        guard let shared = AppGroup.defaults else { return Preferences() }
        let local = UserDefaults.standard
        if shared.object(forKey: favoritesKey) == nil {
            for key in ["favorites", "theme", "appearance", "iconStyle", "interval"] {
                if let value = local.object(forKey: key) { shared.set(value, forKey: key) }
            }
        }
        return Preferences(defaults: shared)
    }
}
