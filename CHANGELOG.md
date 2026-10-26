# Changelog

All notable changes to this project are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/), and versions follow [Semantic Versioning](https://semver.org/).

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

[1.0.1]: https://github.com/garoknows/github-tracker/releases/tag/v1.0.1
[1.0.0]: https://github.com/garoknows/github-tracker/releases/tag/v1.0.0
