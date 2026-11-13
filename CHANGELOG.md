# Changelog

All notable changes to this project are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.2.0] - Unreleased

### Added
- **Optional number next to the menu bar icon.** In **Settings → Number in menu bar**, pick **Last 7 days** (the same days as the 7-day strip), **Current streak** or **Last year total** for your Primary profile. It's off unless you turn it on, so nothing changes when you update. It always matches the card, uses evenly spaced digits so the menu bar doesn't jump, shortens big numbers (12.3k), keeps the last number while offline, and VoiceOver reads it in full ("14 contributions in the last 7 days").

### Fixed
- **The current streak shows the date of its last active day**, like GitHub's own graph labels ("through Nov 12"), in the popover, the Medium and Large widgets and VoiceOver. "Ends today" and "ends yesterday" were misleading in the evening west of UTC, because GitHub groups contributions by UTC day.
- **If GitHub changes the hover text that holds daily counts, the app says so** ("GitHub changed its page, daily counts may be off.") instead of quietly guessing one contribution per colored day. Your last good data stays on screen and is never overwritten by guesses. With a token, the real counts come from GitHub's API instead.
- A favorite whose GitHub account was deleted now says "GitHub has no user named @name anymore" instead of "Offline".
- A changed GitHub page is no longer described as "Offline".
- Adding a favorite downloads its graph once instead of twice.
- A timer refresh and a manual or token refresh at the same moment no longer download the same data twice.
- Widgets label the total "past year" instead of "this year". It always covered the last 12 months, like "in the last year" in the popover.

### Changed
- The install guide pictures and printable guide (PDF) show 1.2.0 and the new setting.
- For contributors: tests that open real windows on screen are skipped unless `TRACKER_LIVE_UI_TESTS=1` is set (see CONTRIBUTING.md).

## [1.1.1] - 2026-11-08

### Fixed
- **Evening contributions no longer drop out of your stats.** GitHub counts days in UTC, so after about 5 pm in the western US its newest day is already "tomorrow." The Total tile, current streak, widget and the 7-day menu bar strip now count that day, and always match the total in the heading.
- **Widgets can use your token.** The token now lives in a Keychain spot the app and its widget share. The first time you open 1.1.1 it moves your saved token there, and **macOS may ask once** to let Tracker for GitHub use it: click **Always Allow**. If a widget can't read the token yet, it says "Open Tracker to use your token" instead of asking you to add one.
- **A brief GitHub slowdown or network drop keeps your Activity overview.** Before, it was replaced with "Add a free token." Now the last good chart stays, with a note, and refreshes again on its own.
- After you add or remove a token, widgets update right away instead of up to 30 minutes later.
- Removing a person while their card was refreshing could bring their saved data back.

### Security
- The app now refuses any request that isn't HTTPS, so a token can never be sent unencrypted.
- The release pipeline is locked down: signing happens in a job that can't publish, versions are validated, third-party actions are pinned, and no token is ever written to disk.

### Changed
- The printable install guide (PDF) is rebuilt from the current instructions, so it no longer shows the old "Open Anyway" steps.
- Uninstalling with Homebrew now quits the app first, and `--zap` also removes its Application Scripts folders. Uninstalling doesn't remove the token from your Keychain; see the install guide for how.

## [1.1.0] - 2026-10-30

### Added
- **Signed and notarized by Apple.** The download now opens like any other Mac app. No more "Open Anyway" step in System Settings.
- **Install with Homebrew:** `brew install --cask garoknows/tap/tracker-for-github`.
- **Widgets follow your app favorites.** New widgets show the people you saved in the app, and update when you change them. Turn off **Use my app favorites** in Edit Widget to type a separate list, as before.
- A **Sponsor** button on the GitHub page, for anyone who wants to support the project.

### Changed
- Your favorites and settings move to a shared space the widget can read. This happens automatically the first time you open 1.1.0.

## [1.0.1] - 2026-10-26

### Fixed
- **The year contribution graph was missing from the menu bar popover.** The popover sized itself before the graph had a height, so the graph got none. The graph now always takes the height its width needs, everywhere: popover, Small, Medium and Large widgets.
- **Hard-to-read popover when Appearance doesn't match macOS.** With Appearance set to Light on a Mac in Dark Mode (or the other way round), the popover's see-through background could stay dark under dark text. The popover now has a solid background that follows the Appearance setting.
- **`scripts/install.sh` could fail to reopen the app** (error -600) when updating a copy that was running. It now waits for the old copy to quit and retries.

### Added
- Regression tests that would have caught both bugs: the graph's size under every kind of layout request, and a test that opens a real popover on screen, checks the graph has room and the background matches the chosen appearance, and saves screenshots.

## [1.0.0] - 2026-10-26

First release.

### Added
- Menu bar app showing anyone's GitHub contribution graph, five stats (total, best day, average, current and longest streak) and the Activity overview quadrant chart.
- Up to 10 favorites, reorderable, with a Primary profile that drives a 7-day menu bar strip (or a simple monochrome icon).
- Flip between favorites with a two-finger swipe, the ← → keys, the ◀ ▶ buttons or the page dots.
- Desktop and Notification Center widgets in Small, Medium and Large, each set up with up to 5 usernames, with ◀ ▶ buttons on Medium and Large.
- Activity overview read from the public profile with no login; an optional read-only token (stored in the Keychain) unlocks a GraphQL fallback.
- Offline cache with "showing data from …" timestamps, polite rate-limit backoff.
- Color themes (GitHub Green, Halloween, Ocean, Mono), System/Light/Dark appearance, Launch at login, Check for updates.
- VoiceOver labels for every graph day and the quadrant chart.

[1.1.1]: https://github.com/garoknows/github-tracker/releases/tag/v1.1.1
[1.1.0]: https://github.com/garoknows/github-tracker/releases/tag/v1.1.0
[1.0.1]: https://github.com/garoknows/github-tracker/releases/tag/v1.0.1
[1.0.0]: https://github.com/garoknows/github-tracker/releases/tag/v1.0.0
