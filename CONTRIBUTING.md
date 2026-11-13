# Contributing

Thanks for helping! Bug reports, ideas and pull requests are all welcome.

## Quick start

You need macOS 14 or later and **Xcode** (free in the Mac App Store).

```sh
git clone https://github.com/garoknows/github-tracker.git
cd github-tracker
./scripts/install-hooks.sh                     # turns on the secret-scan pre-commit hook (needs: brew install gitleaks)
swift test --package-path Packages/TrackerKit  # unit tests, no network needed
open TrackerForGitHub.xcodeproj                # or: ./scripts/install.sh
```

## Project layout

| Folder | What's inside |
|---|---|
| `Packages/TrackerKit` | Everything testable: models, GitHub client, HTML parsers, stats, cache, Keychain, and the SwiftUI views shared by the app and widgets |
| `App/` | The menu bar app: status item, popover, arrow keys and swipe handling |
| `Widgets/` | The WidgetKit extension: Edit Widget configuration and ◀ ▶ App Intents |
| `project.yml` | XcodeGen spec. After changing it, run `xcodegen generate` and commit the updated `TrackerForGitHub.xcodeproj` |
| `docs/` | Install guide, data-source notes, screenshots |
| `site/` | The GitHub Pages site |

## Guidelines

- **Tests first for data code.** If GitHub changes its HTML, add a fixture to `Packages/TrackerKit/Tests/TrackerKitTests/Fixtures/` and a failing test, then fix the parser. See [docs/DATA-SOURCES.md](docs/DATA-SOURCES.md).
- **No third-party runtime dependencies**, no analytics, and no hosts other than `github.com` and `api.github.com`.
- **Never commit secrets.** Tokens belong in the Keychain only. The pre-commit hook and CI run `gitleaks`.
- **Licenses:** this project is MIT. Please don't paste code from GPL projects (for example StreakBar or GitHubContributionsiOS). Learning from how they work is fine.
- Screenshots in `docs/screenshots/` are regenerated with `swift test --package-path Packages/TrackerKit --filter ScreenshotTests`. These draw offscreen; nothing appears on your screen.
- **Tests that open real windows are off by default.** `livePopover` (in `GraphLayoutTests`) shows a real menu bar popover on your screen, in light and then dark, to check the layout with live pixels and to refresh `docs/screenshots/popover-live-*.png`. It's skipped in normal runs and on CI. Turn it on only when regenerating screenshots, and expect windows to flash on screen:

  ```sh
  TRACKER_LIVE_UI_TESTS=1 swift test --package-path Packages/TrackerKit --filter livePopover
  ```

  Any new test that puts a window on screen must use the same switch: `@Test(.enabled(if: LiveUITests.enabled))`.
- The install guide pictures in `docs/install/` are drawn from the website's install section: after changing `site/index.html`, run `swift tools/render-install-figures.swift` from the repo root, then `swift run --package-path tools/docgen docgen .` to rebuild both PDFs.
- Keep the UI matching GitHub's look: Primer neutrals, the 5-level scale, light and dark.

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused, and add or update tests.
3. Make sure `swift test` passes and the app builds.
4. Describe what changed and how you checked it.

By contributing you agree your work is released under the MIT License.
