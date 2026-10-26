import AppKit
import SwiftUI
import Testing
@testable import TrackerKit

/// Renders every view and widget size, light and dark, into docs/screenshots/ so they can be
/// compared with the approved mockups. Uses a real offscreen window so AppKit controls draw.
@MainActor
@Suite("Screenshots", .serialized)
struct ScreenshotTests {
    static let outDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/screenshots", isDirectory: true)

    static let today = CivilDate("2026-10-26")!
    static let fetched = Date(timeIntervalSince1970: 1_793_030_000)
    static let now = fetched.addingTimeInterval(240)

    static func garo() throws -> ProfileSnapshot {
        ProfileSnapshot(
            profile: GitHubProfile(login: "garoknows", name: "Garo", avatarURL: nil),
            calendar: try CalendarParser.parse(try fixture("calendar_active")),
            overview: OverviewParser.parse(try fixture("overview_on")),
            fetchedAt: fetched)
    }

    /// Fictional people, like the mockup's sample profiles.
    static func mira() -> ProfileSnapshot {
        let s = SampleData.snapshot(login: "mira-builds", name: "Mira Patel", today: today, seed: 42)
        return ProfileSnapshot(profile: s.profile, calendar: s.calendar,
                               overview: .available(ActivityOverview(commits: 62, issues: 14, pullRequests: 16, codeReview: 8), source: .publicProfile),
                               fetchedAt: fetched)
    }

    static func theo() -> ProfileSnapshot {
        let s = SampleData.snapshot(login: "nightshift-dev", name: "Theo Novak", today: today, seed: 99)
        return ProfileSnapshot(profile: s.profile, calendar: s.calendar, overview: .off, fetchedAt: fetched)
    }

    static func render<V: View>(_ view: V, name: String, dark: Bool, size: CGSize? = nil) throws {
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        let root = view.environment(\.colorScheme, dark ? .dark : .light)
        let host = NSHostingView(rootView: root)
        host.appearance = appearance
        let fitting = size ?? host.fittingSize
        host.frame = CGRect(origin: .zero, size: fitting)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: outDir.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
    }

    static func popoverBackground(_ dark: Bool) -> Color { dark ? Color(hex: 0x161b22) : Color(hex: 0xffffff) }

    @Test(arguments: [false, true])
    func popoverCard(dark: Bool) throws {
        let card = ProfileCardView(snapshot: try Self.garo(), theme: .green, today: Self.today, now: Self.now)
            .padding(16).frame(width: 520).background(Self.popoverBackground(dark))
        try Self.render(card, name: "popover", dark: dark)

        let noQuad = ProfileCardView(snapshot: Self.theo(), theme: .green, today: Self.today, now: Self.now)
            .padding(16).frame(width: 520).background(Self.popoverBackground(dark))
        try Self.render(noQuad, name: "popover-overview-off", dark: dark)

        let offline = ProfileCardView(snapshot: Self.mira(), theme: .ocean, today: Self.today,
                                      offlineMessage: "Offline, showing data from 2 hr ago.", now: Self.now.addingTimeInterval(7200))
            .padding(16).frame(width: 520).background(Self.popoverBackground(dark))
        try Self.render(offline, name: "popover-offline-ocean", dark: dark)
    }

    func model(favorites: [String]) throws -> AppModel {
        let defaults = UserDefaults(suiteName: "TrackerKitScreenshots-\(UUID().uuidString)")!
        let prefs = Preferences(defaults: defaults)
        prefs.favorites = favorites
        let cache = DiskCache(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let model = AppModel(loader: ProfileLoader(client: GitHubClient(transport: FakeTransport()), cache: cache,
                                                   tokens: MemoryTokenStore()), prefs: prefs)
        for snap in [try Self.garo(), Self.mira(), Self.theo()] where favorites.contains(snap.login) {
            model.setResult(LoadResult(snapshot: snap, error: nil), for: snap.login)
        }
        return model
    }

    @Test(arguments: [false, true])
    func popoverAndSettings(dark: Bool) throws {
        let m = try model(favorites: ["garoknows", "mira-builds", "nightshift-dev"])
        try Self.render(PopoverView(model: m).background(Self.popoverBackground(dark)), name: "popover-full", dark: dark)
        m.screen = .settings
        try Self.render(PopoverView(model: m).background(Self.popoverBackground(dark)), name: "settings", dark: dark)
        let empty = try model(favorites: [])
        try Self.render(PopoverView(model: empty).background(Self.popoverBackground(dark)), name: "welcome", dark: dark)
    }

    @Test(arguments: [false, true])
    func widgets(dark: Bool) throws {
        let sizes: [(WidgetSize, CGSize)] = [(.small, CGSize(width: 170, height: 170)),
                                             (.medium, CGSize(width: 364, height: 170)),
                                             (.large, CGSize(width: 364, height: 382))]
        for (size, frame) in sizes {
            let view = WidgetCardView(snapshot: try Self.garo(), size: size, theme: .green, index: 0, count: 3,
                                      today: Self.today) { NavCircles() }
                .padding(16)
                .frame(width: frame.width, height: frame.height)
                .background(dark ? Color(hex: 0x161b22) : Color(hex: 0xf6f8fa))
                .clipShape(RoundedRectangle(cornerRadius: 22))
            try Self.render(view, name: "widget-\(size.rawValue)", dark: dark, size: frame)
        }
    }

    @Test(arguments: [false, true])
    func menuBarIcons(dark: Bool) throws {
        let snap = try Self.garo()
        let strip = MenuBarIcon.image(style: .strip, snapshot: snap, theme: .green, dark: dark, today: Self.today)
        let glyph = MenuBarIcon.glyph()
        let view = HStack(spacing: 18) {
            Image(nsImage: strip)
            Image(nsImage: glyph).renderingMode(.template).foregroundStyle(dark ? .white : .black)
        }
        .padding(10)
        .background(dark ? Color(hex: 0x1f2328) : Color(hex: 0xf6f8fa))
        try Self.render(view, name: "menubar-icons", dark: dark)
    }

    @Test func themes() throws {
        for dark in [false, true] {
            let view = VStack(alignment: .leading, spacing: 10) {
                ForEach(ColorTheme.allCases) { theme in
                    HStack {
                        Text(theme.name).frame(width: 100, alignment: .leading)
                        LegendView(theme: theme)
                    }
                }
            }
            .padding(14)
            .background(Self.popoverBackground(dark))
            try Self.render(view, name: "themes", dark: dark)
        }
    }
}
