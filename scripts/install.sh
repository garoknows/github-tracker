#!/bin/bash
# Builds Tracker for GitHub from source, copies it to /Applications and opens it.
# Apps you build yourself don't trigger the Gatekeeper "Open Anyway" step.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Tracker for GitHub"
fail() { printf '\n\033[31mError:\033[0m %s\n' "$1" >&2; exit 1; }

# 1. Full Xcode (not just the Command Line Tools) is required to build a Mac app.
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEV_DIR" != *"Xcode"*".app"* ]]; then
  fail "Full Xcode is required (the Command Line Tools alone can't build apps).
  1. Install Xcode from the Mac App Store (free).
  2. Open it once and let it finish setting up.
  3. Run: sudo xcode-select -s /Applications/Xcode.app
  Then run this script again."
fi
if ! xcodebuild -version >/dev/null 2>&1; then
  fail "Xcode is installed but not ready. Open Xcode once to accept the license, or run: sudo xcodebuild -license accept"
fi

# 2. Keep build output out of iCloud: Desktop/Documents syncing tags app bundles and breaks code signing.
BUILD_DIR="${TRACKER_BUILD_DIR:-$HOME/Library/Caches/TrackerForGitHub-build}"
mkdir -p "$BUILD_DIR"
[ -e build.nosync ] || ln -s "$BUILD_DIR" build.nosync

# 3. Regenerate the project if XcodeGen is available (optional; the generated project is committed).
if command -v xcodegen >/dev/null 2>&1; then xcodegen generate --quiet; fi

echo "Building $APP_NAME (Release)… this takes a minute or two the first time."
xcodebuild -project TrackerForGitHub.xcodeproj -scheme TrackerForGitHub -configuration Release \
  -derivedDataPath "$BUILD_DIR/dd" -destination "generic/platform=macOS" -quiet build \
  || fail "The build failed. Scroll up for the first error, or open an issue: https://github.com/garoknows/github-tracker/issues"

BUILT="$BUILD_DIR/dd/Build/Products/Release/$APP_NAME.app"
[ -d "$BUILT" ] || fail "Build finished but the app wasn't found at: $BUILT"

# 4. Quit any running copy and wait until it's really gone (relaunching too soon fails with error -600).
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "Quitting the running copy…"
  pkill -x "$APP_NAME" 2>/dev/null || true
  for _ in $(seq 1 20); do pgrep -x "$APP_NAME" >/dev/null 2>&1 || break; sleep 0.25; done
  pkill -9 -x "$APP_NAME" 2>/dev/null || true
  sleep 1
fi

rm -rf "/Applications/$APP_NAME.app"
ditto "$BUILT" "/Applications/$APP_NAME.app" || fail "Couldn't copy into /Applications. Check you have permission to write there."

echo "Installed to /Applications/$APP_NAME.app. Opening it…"
for attempt in 1 2 3; do
  if open "/Applications/$APP_NAME.app" 2>/dev/null; then
    echo "Done. Look for the small graph icon in your menu bar."
    exit 0
  fi
  sleep 2
done
fail "Installed, but macOS wouldn't open it yet. Open Applications and double-click $APP_NAME."
