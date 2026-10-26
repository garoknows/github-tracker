# Security policy

## Reporting a problem

Please **don't open a public issue** for security problems. Use GitHub's private reporting instead: **Security → Report a vulnerability** on [the repository](https://github.com/garoknows/github-tracker/security/advisories/new).

You'll get a reply within 7 days. Please include steps to reproduce and the app version (Settings → About).

## What the app does with your data

- **No account, no server, no analytics.** The app contacts only `github.com` and `api.github.com` for data, plus GitHub's avatar image host to show profile pictures.
- **Optional token:** stored only in the macOS Keychain. It is never written to disk, UserDefaults or logs, and is only sent to `api.github.com`. It needs **no scopes** (a fine-grained token with public access only, or a classic token with nothing ticked).
- **Cache:** the last good public data for each favorite is saved as JSON in the app's sandbox container (`~/Library/Containers/io.github.garoknows.tracker/`). It contains no secrets.
- The app and widget run in the macOS App Sandbox with only outgoing network access.

## Supported versions

Only the latest release gets fixes.
