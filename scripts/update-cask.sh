#!/bin/bash
# Updates the Homebrew cask's version and sha256.
# Usage: scripts/update-cask.sh path/to/tracker-for-github.rb 1.1.0 <sha256 of the DMG>
set -euo pipefail
CASK="$1"; VERSION="$2"; SHA="$3"
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "Not a sha256: $SHA" >&2; exit 1; }
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK" 2>/dev/null \
  || sed -i -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK"
grep -E '^  (version|sha256) ' "$CASK"
