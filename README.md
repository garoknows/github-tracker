<p align="center">
  <img src="App/Resources/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="96" alt="">
</p>

<h1 align="center">Tracker for GitHub</h1>

<p align="center">
  See anyone's GitHub contribution graph and activity overview in your Mac menu bar and widgets.<br>
  Free, open source, no account, no tracking.
</p>

<p align="center">
  <a href="https://github.com/garoknows/github-tracker/releases/latest"><b>Download for Mac</b></a> ·
  <a href="https://garoknows.github.io/github-tracker/">Website and live demo</a> ·
  <a href="docs/INSTALL.md">Install guide</a> ·
  <a href="#faq">FAQ</a>
</p>

<p align="center">
  <a href="https://github.com/garoknows/github-tracker/actions/workflows/ci.yml"><img src="https://github.com/garoknows/github-tracker/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license">
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/popover-full-dark.png">
    <img src="docs/screenshots/popover-full-light.png" width="520" alt="The menu bar popover: a year of contribution squares, five stats and the activity overview chart">
  </picture>
</p>

## What it does

- **Contribution graph** — the year of green squares, with month and weekday labels and a tooltip on every day ("7 contributions on Oct 21, 2026").
- **Stats** — total for the last year, best day, average per day, current streak and longest streak.
- **Activity overview** — GitHub's four-way chart of Commits, Issues, Pull requests and Code review, read from the public profile. No token needed for most people.
- **Favorites** — keep up to 10 people and flip between them with a two-finger swipe, the ← → keys or the ◀ ▶ buttons. Your Primary profile shows as a 7-day strip right in the menu bar.
- **Widgets** — Small, Medium and Large, on the desktop or in Notification Center, with ◀ ▶ buttons to cycle through up to 5 people.
- **Works offline** — shows the last data it saw, with "Offline, showing data from 2 hr ago."
- **Themes** — GitHub Green, Halloween, Ocean and Mono, in light and dark.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/widget-small-dark.png">
    <img src="docs/screenshots/widget-small-light.png" height="170" alt="Small widget">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/widget-medium-dark.png">
    <img src="docs/screenshots/widget-medium-light.png" height="170" alt="Medium widget">
  </picture>
  <br>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/widget-large-dark.png">
    <img src="docs/screenshots/widget-large-light.png" height="382" alt="Large widget with the activity overview">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/settings-dark.png">
    <img src="docs/screenshots/settings-light.png" height="382" alt="Settings">
  </picture>
</p>

## Install

1. Download **Tracker-for-GitHub-x.y.z.dmg** from the [latest release](https://github.com/garoknows/github-tracker/releases/latest).
2. Open it and drag **Tracker for GitHub** into **Applications**.
3. Open the app. The first time, macOS shows a warning. That's expected (see below).
4. Click the graph icon in your menu bar and type a GitHub username.

Step-by-step pictures: **[docs/INSTALL.md](docs/INSTALL.md)** (also as a [printable PDF](docs/Tracker-for-GitHub-Install-Guide.pdf)).

### About the "Open Anyway" step

This app is free and isn't signed with a paid Apple Developer account yet, so the first time you open it, macOS says it "could not verify" the app. That's normal for small open-source apps. You approve it once:

1. Click **Done** on the warning.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** next to "Tracker for GitHub was blocked."
3. Confirm with your password or Touch ID.

On macOS 15 and later the old right-click → Open shortcut no longer works, so use System Settings. If you'd rather skip this step entirely, build it yourself (below). Apps you build on your own Mac don't get the warning.

## Build from source

You need macOS 14+ and **Xcode** (free in the Mac App Store).

```sh
git clone https://github.com/garoknows/github-tracker.git
cd github-tracker
./scripts/install.sh
```

The script builds a Release copy, puts it in `/Applications` and opens it. It prints a clear message if Xcode is missing.

For development, run `swift test --package-path Packages/TrackerKit` for the unit tests (no network needed), and see [CONTRIBUTING.md](CONTRIBUTING.md). The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## FAQ

**Why is the quadrant chart missing for someone?**
GitHub only shows "Activity overview" for people who turned it on in their profile settings. If they did and it's still missing, paste a free read-only token in Settings. It needs no permissions at all ([create one](https://github.com/settings/personal-access-tokens/new)).

**Does it show private work?**
Only as anonymous squares, and only if that person turned on "Private contributions" on their profile. Private repo names and code are never shown. That's how GitHub's own profile works too.

**Does the total match github.com?**
Yes. The graph comes from the same public page GitHub uses for profiles, and the colors use GitHub's own intensity levels.

**Why can't I swipe the widgets?**
macOS widgets only support clicks on buttons, so they have ◀ ▶ instead. Swiping works in the menu bar popover.

**Can the widgets use my app favorites?**
Not in this free build. Sharing settings between an app and its widgets needs an Apple Developer signing team (App Groups). For now each widget is set up with Edit Widget, which takes about 10 seconds.

**How often does it refresh?**
Every 30 minutes by default (15 min to 3 hr in Settings). Widgets refresh about every 30 minutes. Refresh in the popover updates right away.

**Something broke after GitHub changed its site.**
Please [open an issue](https://github.com/garoknows/github-tracker/issues). All of GitHub's page format is handled in one place with saved test pages, so fixes are quick. See [docs/DATA-SOURCES.md](docs/DATA-SOURCES.md).

## Privacy

- No account, no server, no analytics, no third-party code.
- The app talks only to **github.com** and **api.github.com**, plus GitHub's avatar image host for profile pictures.
- The optional token lives only in your **macOS Keychain**. It's never written to disk or logs, and only ever sent to GitHub.
- The app and widgets run in Apple's App Sandbox with outgoing network access only.

Details in [SECURITY.md](SECURITY.md).

## Credits

Built with ideas (not code) from these projects. Thank you!

| Project | License | What it inspired |
|---|---|---|
| [menubar-apps/StreakBar](https://github.com/menubar-apps/StreakBar) | GPL-3.0 | Menu bar graph, Homebrew tap |
| [JustinFincher/GitHubContributionsiOS](https://github.com/JustinFincher/GitHubContributionsiOS) | GPL-3.0 | Contribution widgets |
| [lukaskaibel/issues-for-github](https://github.com/lukaskaibel/issues-for-github) | MIT | Reference for the planned v2 sign-in and issue cards |
| [mohummudh/contributions](https://github.com/mohummudh/contributions) | No license declared | Unauthenticated scraping in a native widget |
| [Jeetchavan02/Macos-Github-Widget](https://github.com/Jeetchavan02/Macos-Github-Widget) | No license declared | Swift 6 widget, offline cache |
| [SekulDev/GithubContributionWidgetMacOS](https://github.com/SekulDev/GithubContributionWidgetMacOS) | MIT | One-command install script |

No code from the GPL-licensed projects was copied into this MIT project.

## License

[MIT](LICENSE) © garoknows

---

<sub>Tracker for GitHub is an independent project. It is not affiliated with, endorsed by, or sponsored by GitHub, Inc. "GitHub" is a trademark of GitHub, Inc.</sub>
