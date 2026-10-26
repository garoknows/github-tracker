import AppIntents
import SwiftUI
import TrackerKit
import WidgetKit

@main
struct TrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        ContributionWidget()
    }
}

struct ContributionWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "ContributionWidget", intent: ProfilesIntent.self, provider: Provider()) { entry in
            ContributionWidgetView(entry: entry)
        }
        .configurationDisplayName("GitHub contributions")
        .description("A GitHub contribution graph. Right-click and choose Edit Widget to pick up to 5 people.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: Configuration (Edit Widget)

enum ThemeOption: String, AppEnum {
    case green, halloween, ocean, mono

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Color theme"
    static let caseDisplayRepresentations: [ThemeOption: DisplayRepresentation] = [
        .green: "GitHub Green", .halloween: "Halloween", .ocean: "Ocean", .mono: "Mono"
    ]

    var theme: ColorTheme { ColorTheme(rawValue: rawValue) ?? .green }
}

/// Self-contained setup: unsigned builds can't share the app's favorites, so each widget keeps its own list.
struct ProfilesIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "GitHub profiles"
    static let description = IntentDescription("Type up to 5 GitHub usernames. Use ◀ ▶ on the widget to flip between them.")

    @Parameter(title: "Username 1") var user1: String?
    @Parameter(title: "Username 2") var user2: String?
    @Parameter(title: "Username 3") var user3: String?
    @Parameter(title: "Username 4") var user4: String?
    @Parameter(title: "Username 5") var user5: String?
    @Parameter(title: "Color theme", default: .green) var theme: ThemeOption

    init() {}

    /// Valid, de-duplicated usernames in the order typed.
    var logins: [String] {
        var seen = Set<String>()
        return [user1, user2, user3, user4, user5].compactMap { raw in
            guard let raw, let login = try? Username.normalize(raw), seen.insert(login.lowercased()).inserted else { return nil }
            return login
        }
    }
}

// MARK: ◀ ▶ buttons

/// Remembers which person each widget configuration is showing.
enum WidgetPage {
    static func index(for key: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let stored = UserDefaults.standard.integer(forKey: "page.\(key)")
        return ((stored % count) + count) % count
    }

    static func shift(_ key: String, by delta: Int, count: Int) {
        guard count > 0 else { return }
        let next = ((index(for: key, count: count) + delta) % count + count) % count
        UserDefaults.standard.set(next, forKey: "page.\(key)")
    }
}

struct ShiftProfileIntent: AppIntent {
    static let title: LocalizedStringResource = "Show another profile"
    static let isDiscoverable = false

    @Parameter(title: "Widget") var key: String
    @Parameter(title: "Step") var delta: Int
    @Parameter(title: "Count") var count: Int

    init() {}

    init(key: String, delta: Int, count: Int) {
        self.key = key
        self.delta = delta
        self.count = count
    }

    func perform() async throws -> some IntentResult {
        WidgetPage.shift(key, by: delta, count: count)
        return .result()
    }
}

// MARK: Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: ProfileSnapshot?
    let avatar: Data?
    let theme: ColorTheme
    let index: Int
    let count: Int
    let key: String
    let message: String?
}

struct Provider: AppIntentTimelineProvider {
    let loader = ProfileLoader()

    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: SampleData.snapshot(), avatar: nil, theme: .green, index: 0, count: 3, key: "", message: nil)
    }

    func snapshot(for configuration: ProfilesIntent, in context: Context) async -> Entry {
        if context.isPreview && configuration.logins.isEmpty { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: ProfilesIntent, in context: Context) async -> Timeline<Entry> {
        let e = await entry(for: configuration)
        return Timeline(entries: [e], policy: .after(Date().addingTimeInterval(30 * 60)))
    }

    private func entry(for configuration: ProfilesIntent) async -> Entry {
        let logins = configuration.logins
        let key = logins.joined(separator: ",").lowercased()
        let index = WidgetPage.index(for: key, count: logins.count)
        guard logins.indices.contains(index) else {
            return Entry(date: Date(), snapshot: nil, avatar: nil, theme: configuration.theme.theme, index: 0, count: 0, key: key, message: nil)
        }
        let result = await loader.load(logins[index])
        let avatar = await avatarData(result.snapshot?.profile.avatarURL)
        let message = result.snapshot == nil ? result.error?.errorDescription : nil
        return Entry(date: Date(), snapshot: result.snapshot, avatar: avatar, theme: configuration.theme.theme,
                     index: index, count: logins.count, key: key, message: message)
    }

    /// Widgets can't load images lazily, so fetch a small avatar up front (GitHub's own image host).
    private func avatarData(_ url: URL?) async -> Data? {
        guard let url, url.host?.hasSuffix("githubusercontent.com") == true,
              var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "s", value: "96")]
        guard let sized = c.url else { return nil }
        var request = URLRequest(url: sized, timeoutInterval: 10)
        request.setValue(GitHubClient.userAgent, forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: request).0
    }
}

// MARK: View

struct ContributionWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let message = entry.message {
                Text(message)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette(scheme).muted)
            } else {
                WidgetCardView(snapshot: entry.snapshot, size: size, theme: entry.theme, index: entry.index,
                               count: entry.count, avatarData: entry.avatar) {
                    if entry.count > 1 {
                        HStack(spacing: 6) {
                            navButton("arrowtriangle.left.fill", "Previous profile", delta: -1)
                            navButton("arrowtriangle.right.fill", "Next profile", delta: 1)
                        }
                    }
                }
            }
        }
        .widgetURL(entry.snapshot?.profileURL)
        .containerBackground(for: .widget) {
            scheme == .dark ? Color(hex: 0x161b22) : Color(hex: 0xf6f8fa)
        }
    }

    private var size: WidgetSize {
        switch family {
        case .systemSmall: .small
        case .systemLarge, .systemExtraLarge: .large
        default: .medium
        }
    }

    private func navButton(_ symbol: String, _ label: String, delta: Int) -> some View {
        Button(intent: ShiftProfileIntent(key: entry.key, delta: delta, count: entry.count)) {
            Image(systemName: symbol)
                .font(.system(size: 9))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Palette(scheme).surface))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette(scheme).fg)
        .accessibilityLabel(label)
    }
}
