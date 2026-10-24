#!/bin/bash
# Boil an xcodebuild / swift log, or an .xcresult bundle, down to what needs fixing.
#
# Usage: .claude/skills/mac-build/scripts/summarize-log.sh <file.log | bundle.xcresult | run folder> [max lines]
# For a run folder (build/mac/<timestamp>) prints its summary.md followed by the error lines of every failed log.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
IN="${1:?log file, .xcresult or run folder}"; MAX="${2:-60}"

if [ -d "$IN" ] && [ -f "$IN/summary.md" ]; then
  cat "$IN/summary.md"
  exit 0
fi

if [ -d "$IN" ] && [[ "$IN" == *.xcresult ]]; then
  # Xcode 16+: a compact test summary; older: the legacy JSON.
  if xcrun xcresulttool get test-results summary --path "$IN" >/dev/null 2>&1; then
    xcrun xcresulttool get test-results summary --path "$IN" --compact 2>/dev/null | head -c 20000
    echo
    xcrun xcresulttool get test-results tests --path "$IN" --compact 2>/dev/null \
      | tr ',' '\n' | grep -E '"result":"Failed"|"name":' | paste - - 2>/dev/null | grep Failed | head -"$MAX"
  else
    xcrun xcresulttool get --format json --path "$IN" | head -c 20000
  fi
  exit 0
fi

[ -f "$IN" ] || { echo "no such file $IN" >&2; exit 2; }

echo "## Errors ($(error_lines "$IN" 100000 | wc -l | tr -d ' ') unique lines, showing up to $MAX)"
error_lines "$IN" "$MAX"
echo
echo "## Failed tests"
grep -hE "Test Case '.*' failed|XCTAssert|error: -\[" "$IN" | sort -u | head -"$MAX"
echo
echo "## Warnings worth a look (deprecations, Sendable, unused)"
grep -hE 'warning:' "$IN" | grep -vE 'DerivedData|SourcePackages' | sort -u | head -20
echo
echo "## Verdict"
if grep -qE '\*\* (BUILD|TEST) FAILED|error:|Fatal error|Test Suite .* failed' "$IN"; then echo "FAILED"; else echo "PASSED (no error lines)"; fi
