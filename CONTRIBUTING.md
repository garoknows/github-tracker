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
- Screenshots in `docs/screenshots/` are regenerated with `swift test --package-path Packages/TrackerKit --filter Screenshot`.
- Keep the UI matching GitHub's look: Primer neutrals, the 5-level scale, light and dark.

## Pull requests

1. Fork and branch from `main`.
2. Keep changes focused, and add or update tests.
3. Make sure `swift test` passes and the app builds.
4. Describe what changed and how you checked it.

By contributing you agree your work is released under the MIT License.
