#!/bin/bash
# Updates the Homebrew cask's version and sha256 lines, and nothing else
# (scripts/test-update-cask.sh checks that in CI).
# Usage: scripts/update-cask.sh path/to/tracker-for-github.rb 1.1.0 <sha256 of the DMG>
set -euo pipefail
CASK="$1"; VERSION="$2"; SHA="$3"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "Not a version: $VERSION" >&2; exit 1; }
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "Not a sha256: $SHA" >&2; exit 1; }
[ "$(grep -cE '^  version "' "$CASK")" -eq 1 ] && [ "$(grep -cE '^  sha256 "' "$CASK")" -eq 1 ] \
  || { echo "Expected exactly one version and one sha256 line in $CASK" >&2; exit 1; }
TMP="$(mktemp "${TMPDIR:-/tmp}/cask.XXXXXX")"
sed -E "s/^  version \".*\"$/  version \"$VERSION\"/; s/^  sha256 \".*\"$/  sha256 \"$SHA\"/" "$CASK" > "$TMP"
cat "$TMP" > "$CASK"
rm -f "$TMP"
grep -E '^  (version|sha256) ' "$CASK"
