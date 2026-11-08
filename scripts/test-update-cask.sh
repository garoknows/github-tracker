#!/bin/bash
# Checks that scripts/update-cask.sh changes only the version and sha256 lines of the cask,
# so hand-written parts (uninstall quit:, zap trash:) survive every release.
# Runs in CI. Usage: scripts/test-update-cask.sh
set -euo pipefail
cd "$(dirname "$0")/.."

WORK="$(mktemp -d "${TMPDIR:-/tmp}/cask-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
cp scripts/testdata/tracker-for-github.rb "$WORK/before.rb"
cp scripts/testdata/tracker-for-github.rb "$WORK/after.rb"

SHA="$(printf '%064d' 7 | tr 0 a)"
scripts/update-cask.sh "$WORK/after.rb" "9.8.7" "$SHA" > /dev/null

fail() { echo "update-cask test failed: $*" >&2; diff "$WORK/before.rb" "$WORK/after.rb" >&2 || true; exit 1; }

grep -qx '  version "9.8.7"' "$WORK/after.rb" || fail "version line not updated"
grep -qx "  sha256 \"$SHA\"" "$WORK/after.rb" || fail "sha256 line not updated"

# Every other line must be byte-for-byte the same.
grep -vE '^  (version|sha256) ' "$WORK/before.rb" > "$WORK/before.rest"
grep -vE '^  (version|sha256) ' "$WORK/after.rb" > "$WORK/after.rest"
cmp -s "$WORK/before.rest" "$WORK/after.rest" || fail "lines other than version and sha256 changed"
[ "$(wc -l < "$WORK/before.rb")" -eq "$(wc -l < "$WORK/after.rb")" ] || fail "line count changed"
grep -q 'uninstall quit: "io.github.garoknows.tracker"' "$WORK/after.rb" || fail "uninstall quit: was lost"
grep -q 'Application Scripts/io.github.garoknows.tracker.widgets' "$WORK/after.rb" || fail "zap entries were lost"

# Bad input is refused and leaves the file alone.
cp "$WORK/before.rb" "$WORK/bad.rb"
if scripts/update-cask.sh "$WORK/bad.rb" '1.0"; system("x")' "$SHA" 2> /dev/null; then fail "accepted a malformed version"; fi
if scripts/update-cask.sh "$WORK/bad.rb" "1.2.3" "not-a-sha" 2> /dev/null; then fail "accepted a malformed sha256"; fi
cmp -s "$WORK/before.rb" "$WORK/bad.rb" || fail "a refused update still changed the file"

echo "update-cask.sh only touches version and sha256: OK"
