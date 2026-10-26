# Tracker for GitHub: why it matters and what it could become

_A one-page thesis for a free, open-source Mac app. October 2026._

## The bet
The GitHub contribution graph is the most-looked-at picture of a developer's work. It's on every profile and it shows up in résumés and hiring screens, and plenty of people keep their streaks going just to see it stay green. But you have to open a browser and go looking for it. Tracker for GitHub puts that picture, and GitHub's own "Activity overview" chart, where people already look: the Mac menu bar, the desktop and Notification Center. It doesn't need an account, a server or any tracking.

## Why now
- **The existing tools are abandoned.** Most Mac and iOS contribution widgets haven't been updated in years. Their App Store reviews say things like "every username is invalid."
- **Nobody shows the Activity overview.** The four-way Commits / Issues / Pull requests / Code review chart is one of the most telling parts of a profile, and no menu bar or widget tool shows it. We verified it can be read publicly, with no login.
- **macOS 14 made widgets interactive.** Desktop widgets with real buttons make "flip through the people I follow" possible for the first time.

## Who it's for
1. **Builders keeping a streak.** A 7-day strip in the menu bar is a gentle daily nudge.
2. **People who follow people.** Managers, mentors, teachers and friends can keep up to 10 favorites and swipe through their cards.
3. **Widget people.** A glanceable graph on the desktop that refreshes itself.

## How an open-source tool like this grows
- **It markets itself.** Every screenshot of a green widget is an ad, and the users are developers who post their setups.
- **GitHub-native distribution.** The README, topics, Releases, a Pages site, and "awesome-macos" lists. Later a Homebrew tap and a Show HN post.
- **Trust as the feature.** No analytics, MIT license, public code and a Keychain-only token. For a tool that reads activity data, that's what earns installs.
- **Contributors.** Parsing lives in one tested module with saved fixtures, so outside fixes are easy and safe. "Good first issues" turn users into maintainers.
- **Sustainability.** GitHub Sponsors and "buy me a coffee." There's no paid tier and no lock-in.

## What v2 and beyond could become
- **v2: your work, not just your graph.** Sign in with GitHub to see open issues as clean cards grouped by repo, with label filters and one-click close, plus "my open issues" widgets.
- **Teams and cohorts.** A small dashboard for a bootcamp class or an open-source team, built on the same public data.
- **Goals.** Streak reminders, weekly summaries and gentle "you're one day from a record" nudges, all local.
- **Everywhere you look.** iPhone and iPad widgets, Apple Watch complications, and a signed, notarized build with a Homebrew install.
- **Beyond GitHub.** The same idea for GitLab and Codeberg, behind the same tested parser design.

## What success looks like in year one
Steady release downloads, stars and outside pull requests, plus issue reports that get fixed within days when GitHub changes its pages. There are no analytics on purpose, so downloads, stars and contributors are the scoreboard.
