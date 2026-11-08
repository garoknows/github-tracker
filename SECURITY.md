# Security policy

## Reporting a problem

Please **don't open a public issue** for security problems. Use GitHub's private reporting instead: **Security → Report a vulnerability** on [the repository](https://github.com/garoknows/github-tracker/security/advisories/new).

You'll get a reply within 7 days. Please include steps to reproduce and the app version (Settings → About).

## What the app does with your data

- **No account, no server, no analytics.** The app contacts only `github.com` and `api.github.com` for data, plus GitHub's avatar image host to show profile pictures.
- **Optional token:** stored only in the macOS Keychain. It is never written to disk, UserDefaults, the shared App Group folder, the cache or logs, and is only sent to `api.github.com` over HTTPS. It needs **no scopes** (a fine-grained token with public access only, or a classic token with nothing ticked).
  - Signed releases (1.1.1 and later) keep it in the data protection keychain under the access group `<Team ID>.io.github.garoknows.tracker`, which only the app and its widget (signed by the same developer team) can read. The first launch of 1.1.1 moves a token saved by an older version there and deletes the old copy; macOS may ask once to allow that.
  - Unsigned builds (from `scripts/install.sh`) keep it in the login keychain, readable only by the app itself. Their widget can't read it and says "Open Tracker to use your token."
  - Uninstalling the app does not delete the token. To remove it, delete it in Settings before uninstalling, or open **Keychain Access**, search for `io.github.garoknows.tracker`, and delete that item.
- **Cache:** the last good public data for each favorite is saved as JSON in the app's sandbox container (`~/Library/Containers/io.github.garoknows.tracker/`). It contains no secrets.
- The app and widget run in the macOS App Sandbox with only outgoing network access.

## Supported versions

Only the latest release gets fixes.
