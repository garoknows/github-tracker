import AppKit
import SwiftUI

// Shared look: GitHub Primer neutrals, the green contribution scale, the 3×3 brand mark.
enum Style {
    static let fg = Color(red: 0x1f / 255, green: 0x23 / 255, blue: 0x28 / 255)
    static let muted = Color(red: 0x59 / 255, green: 0x63 / 255, blue: 0x6e / 255)
    static let border = Color(red: 0xd1 / 255, green: 0xd9 / 255, blue: 0xe0 / 255)
    static let canvas = Color(red: 0xf6 / 255, green: 0xf8 / 255, blue: 0xfa / 255)
    static let green = Color(red: 0x1a / 255, green: 0x7f / 255, blue: 0x37 / 255)
    static let dark = Color(red: 0x0d / 255, green: 0x11 / 255, blue: 0x17 / 255)
    static let scale: [Color] = [0xeff2f5, 0xaceebb, 0x4ac26b, 0x2da44e, 0x116329].map {
        Color(red: Double(($0 >> 16) & 0xff) / 255, green: Double(($0 >> 8) & 0xff) / 255, blue: Double($0 & 0xff) / 255)
    }
}

struct BrandMark: View {
    var size: CGFloat
    var body: some View {
        let levels = [1, 3, 2, 4, 2, 0, 3, 1, 4]
        Grid(horizontalSpacing: size * 0.08, verticalSpacing: size * 0.08) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: size * 0.06).fill(Style.scale[levels[r * 3 + c]])
                            .frame(width: size * 0.28, height: size * 0.28)
                    }
                }
            }
        }
    }
}

/// A decorative strip of contribution squares.
struct Squares: View {
    var columns: Int
    var cell: CGFloat
    var body: some View {
        HStack(spacing: cell * 0.3) {
            ForEach(0..<columns, id: \.self) { c in
                VStack(spacing: cell * 0.3) {
                    ForEach(0..<7, id: \.self) { r in
                        let n = (c * 7 + r) * 2654435761 % 97
                        let level = c > columns - 5 ? (n % 4) + 1 : (n < 12 ? n % 3 + 1 : 0)
                        RoundedRectangle(cornerRadius: cell * 0.2).fill(Style.scale[level]).frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

// MARK: Thesis (one US Letter page)

struct Section: View {
    let title: String
    let items: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11.5, weight: .bold)).foregroundStyle(Style.green)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    RoundedRectangle(cornerRadius: 1).fill(Style.scale[3]).frame(width: 4, height: 4).offset(y: -1)
                    Text(.init(item)).font(.system(size: 8.6)).foregroundStyle(Style.fg).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ThesisPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 12) {
                BrandMark(size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tracker for GitHub").font(.system(size: 20, weight: .bold)).foregroundStyle(Style.fg)
                    Text("Why it matters and what it could become · a one-page thesis · October 2026")
                        .font(.system(size: 9)).foregroundStyle(Style.muted)
                }
                Spacer()
                Squares(columns: 10, cell: 5)
            }
            Text("**The bet.** The GitHub contribution graph is the most-looked-at picture of a developer's work. It's on every profile and shows up in résumés and hiring screens, and plenty of people keep their streaks going just to see it stay green. But you have to open a browser and go looking for it. Tracker for GitHub puts that picture, and GitHub's own Activity overview chart, in the Mac menu bar, on the desktop and in Notification Center. It doesn't need an account, a server or any tracking.")
                .font(.system(size: 9.4)).foregroundStyle(Style.fg).fixedSize(horizontal: false, vertical: true)
                .padding(10).background(RoundedRectangle(cornerRadius: 8).fill(Style.canvas))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Style.border))
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 11) {
                    Section(title: "Why now", items: [
                        "**The existing tools are abandoned.** Most contribution widgets haven't been updated in years. Their reviews say things like \"every username is invalid.\"",
                        "**Nobody shows the Activity overview.** We verified the Commits / Issues / PRs / Code review chart can be read publicly, with no login.",
                        "**macOS 14 made widgets interactive**, so \"flip through the people I follow\" works on the desktop for the first time.",
                    ])
                    Section(title: "Who it's for", items: [
                        "**Builders keeping a streak.** A 7-day strip in the menu bar is a gentle daily nudge.",
                        "**People who follow people.** Managers, mentors, teachers and friends can swipe through up to 10 favorites.",
                        "**Widget people.** A glanceable graph on the desktop that refreshes itself.",
                    ])
                    Section(title: "What success looks like in year one", items: [
                        "Steady release downloads, stars and outside pull requests.",
                        "Fixes within days whenever GitHub changes its pages.",
                        "There are no analytics on purpose, so downloads, stars and contributors are the scoreboard.",
                    ])
                }
                VStack(alignment: .leading, spacing: 11) {
                    Section(title: "How an open-source tool like this grows", items: [
                        "**It markets itself.** Every screenshot of a green widget is an ad, and developers post their setups.",
                        "**GitHub-native distribution.** README, topics, Releases and a Pages site, then a Homebrew tap and a Show HN post.",
                        "**Trust as the feature.** No analytics, MIT license, public code and a Keychain-only token.",
                        "**Contributors.** One tested parser module with saved fixtures makes outside fixes easy and safe.",
                        "**Sustainability.** GitHub Sponsors. No paid tier, no lock-in.",
                    ])
                    Section(title: "What v2 and beyond could become", items: [
                        "**v2: your work, not just your graph.** Sign in to see open issues as cards by repo, with label filters, one-click close and \"my issues\" widgets.",
                        "**Teams and cohorts.** A small dashboard for a class or an open-source team.",
                        "**Goals.** Local streak reminders and weekly summaries.",
                        "**Everywhere.** iPhone and iPad widgets, a notarized build and Homebrew.",
                        "**Beyond GitHub.** GitLab and Codeberg, using the same tested design.",
                    ])
                }
            }
            Spacer(minLength: 0)
            HStack {
                Text("github.com/garoknows/github-tracker · MIT license · Not affiliated with GitHub, Inc.")
                Spacer()
                Text("garoknows.github.io/github-tracker")
            }
            .font(.system(size: 7.5)).foregroundStyle(Style.muted)
        }
        .padding(.horizontal, 40).padding(.vertical, 36)
        .frame(width: 612, height: 792, alignment: .topLeading)
        .background(Color.white)
    }
}

// MARK: Deck (6 slides, 16:9)

struct Slide<Content: View>: View {
    let number: Int
    let kicker: String
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(spacing: 10) {
                BrandMark(size: 26)
                Text(kicker.uppercased()).font(.system(size: 15, weight: .semibold)).tracking(1.2).foregroundStyle(Style.green)
                Spacer()
                Text("\(number) / 6").font(.system(size: 14)).foregroundStyle(Style.muted)
            }
            Text(title).font(.system(size: 46, weight: .bold)).foregroundStyle(Style.fg).fixedSize(horizontal: false, vertical: true)
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            HStack {
                Text("Tracker for GitHub").font(.system(size: 13, weight: .semibold))
                Text("· free, open source, MIT").font(.system(size: 13))
                Spacer()
                Squares(columns: 14, cell: 7)
            }
            .foregroundStyle(Style.muted)
        }
        .padding(64)
        .frame(width: 1280, height: 720, alignment: .topLeading)
        .background(Color.white)
    }
}

struct Bullets: View {
    let items: [String]
    var size: CGFloat = 24
    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.7) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    RoundedRectangle(cornerRadius: 3).fill(Style.scale[3]).frame(width: size * 0.45, height: size * 0.45)
                    Text(.init(item)).font(.system(size: size)).foregroundStyle(Style.fg).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct Card: View {
    let title: String
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 24, weight: .bold)).foregroundStyle(Style.fg)
            Text(text).font(.system(size: 18)).foregroundStyle(Style.muted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Style.canvas))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Style.border))
    }
}

func image(_ root: URL, _ path: String) -> Image {
    Image(nsImage: NSImage(contentsOf: root.appendingPathComponent(path)) ?? NSImage())
}

@MainActor
func slides(root: URL) -> [AnyView] {
    [
        AnyView(
            VStack(alignment: .leading, spacing: 30) {
                HStack(spacing: 18) {
                    BrandMark(size: 72)
                    Text("Tracker for GitHub").font(.system(size: 64, weight: .bold)).foregroundStyle(.white)
                }
                Text("Anyone's GitHub year, in your Mac menu bar and widgets.")
                    .font(.system(size: 34, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                Spacer()
                Squares(columns: 40, cell: 16)
                Text("Free · open source (MIT) · no account · no tracking · October 2026")
                    .font(.system(size: 18)).foregroundStyle(.white.opacity(0.7))
            }
            .padding(72)
            .frame(width: 1280, height: 720, alignment: .topLeading)
            .background(Style.dark)
        ),
        AnyView(Slide(number: 2, kicker: "The problem", title: "The best picture of a developer's work is hidden in a browser tab") {
            Bullets(items: [
                "The contribution graph is on every profile and in hiring screens, and plenty of people keep streaks just to see it green.",
                "The Mac tools that showed it are **abandoned**. Reviews say \"every username is invalid.\"",
                "**None** show GitHub's Activity overview, the Commits / Issues / PRs / Code review chart.",
                "None let you **flip between several people**.",
            ])
        }),
        AnyView(Slide(number: 3, kicker: "The product", title: "Glance, swipe, done") {
            HStack(alignment: .top, spacing: 36) {
                image(root, "docs/screenshots/popover-full-light.png").resizable().scaledToFit()
                    .frame(width: 360).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Style.border))
                VStack(alignment: .leading, spacing: 20) {
                    Bullets(items: [
                        "Year graph, 5 stats and the **Activity overview** quadrant",
                        "Up to 10 favorites: **swipe**, ← →, or ◀ ▶",
                        "Small, Medium, Large **widgets** with buttons",
                        "Offline cache, 4 color themes, light and dark",
                    ], size: 21)
                    HStack(spacing: 14) {
                        image(root, "docs/screenshots/widget-small-light.png").resizable().scaledToFit().frame(height: 120)
                        image(root, "docs/screenshots/widget-medium-light.png").resizable().scaledToFit().frame(height: 120)
                    }
                }
            }
        }),
        AnyView(Slide(number: 4, kicker: "Who it's for", title: "Three kinds of people check this every day") {
            HStack(spacing: 22) {
                Card(title: "Streak builders", text: "\"Show my green squares in the menu bar so I keep my streak going.\" A 7-day strip is a gentle daily nudge.")
                Card(title: "People who follow people", text: "Managers, mentors, teachers and friends keep up to 10 favorites and swipe through their cards.")
                Card(title: "Widget people", text: "\"Put the graph on my desktop and never open an app.\" Small, Medium and Large, refreshing themselves.")
            }
        }),
        AnyView(Slide(number: 5, kicker: "How it grows", title: "Open source that markets itself") {
            HStack(alignment: .top, spacing: 40) {
                Bullets(items: [
                    "**Screenshots are ads.** Developers post their setups.",
                    "**GitHub-native distribution:** README, topics, Releases, Pages, then a Homebrew tap and Show HN.",
                    "**Trust is the feature:** no analytics, MIT, Keychain-only token.",
                ], size: 22)
                Bullets(items: [
                    "**Easy to contribute:** one tested parser with saved fixtures.",
                    "**Sustainable:** GitHub Sponsors, no paid tier, no lock-in.",
                    "**Scoreboard:** downloads, stars, outside PRs, fix time when GitHub changes.",
                ], size: 22)
            }
        }),
        AnyView(Slide(number: 6, kicker: "What's next", title: "From your graph to your work") {
            HStack(spacing: 22) {
                Card(title: "v2 · Issues as cards", text: "Sign in with GitHub. Open issues by repo, label filters, one-click close, \"my issues\" widgets.")
                Card(title: "Teams and goals", text: "Cohort dashboards for classes and OSS teams. Local streak reminders and weekly summaries.")
                Card(title: "Everywhere", text: "Notarized build and Homebrew. iPhone and iPad widgets. GitLab and Codeberg support.")
            }
        }),
    ]
}

@MainActor
func renderPDF(_ views: [AnyView], size: CGSize, to url: URL) {
    var box = CGRect(origin: .zero, size: size)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, [kCGPDFContextTitle as String: "Tracker for GitHub"] as CFDictionary) else {
        fatalError("Can't create \(url.path)")
    }
    for view in views {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.render { _, draw in
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
        }
    }
    ctx.closePDF()
    print("Wrote \(url.path)")
}

@MainActor
func run() {
    let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".", isDirectory: true)
    let out = root.appendingPathComponent("docs/thesis", isDirectory: true)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    renderPDF([AnyView(ThesisPage())], size: CGSize(width: 612, height: 792), to: out.appendingPathComponent("THESIS.pdf"))
    renderPDF(slides(root: root), size: CGSize(width: 1280, height: 720), to: out.appendingPathComponent("DECK.pdf"))
}

MainActor.assumeIsolated { run() }
