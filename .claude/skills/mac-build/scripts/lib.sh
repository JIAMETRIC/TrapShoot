#!/bin/bash
# Shared helpers for the mac-build scripts. Source it; do not run it.

# Repository root (scripts live in .claude/skills/mac-build/scripts).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Where this run writes logs, result bundles and the summary.
RUN_DIR="${RUN_DIR:-$REPO_ROOT/build/mac/$(date +%Y%m%d-%H%M%S)}"
DERIVED="${DERIVED:-$REPO_ROOT/build/mac/DerivedData}"

# Simulator used for tests and runs. Override with SIM="iPhone 17 Pro".
pick_sim() {
  if [ -n "${SIM:-}" ]; then echo "$SIM"; return; fi
  # Prefer the newest iPhone Pro, then any iPhone.
  local name
  name=$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [0-9]+ Pro \(' | sed 's/ ($//' | sort -V | tail -1)
  [ -z "$name" ] && name=$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [0-9A-Za-z ]+\(' | sed 's/ ($//' | sort -V | tail -1)
  echo "${name:-iPhone 16}"
}

# Pipe xcodebuild output through a formatter when one exists; the tee keeps the full log.
fmt() {
  if command -v xcbeautify >/dev/null 2>&1; then xcbeautify --quiet; elif command -v xcpretty >/dev/null 2>&1; then xcpretty; else cat; fi
}

# Record a step result in the summary. status: pass|fail|skip
record() {
  local step="$1" status="$2" log="$3" secs="$4"
  printf '| %s | %s | %ss | %s |\n' "$step" "$status" "$secs" "${log#$REPO_ROOT/}" >> "$RUN_DIR/summary.md"
}

# Run a step: run_step <name> <command...>. Never aborts the run; records pass/fail.
run_step() {
  local name="$1"; shift
  local log="$RUN_DIR/$name.log" start end status
  start=$(date +%s)
  echo "=== $name"
  if ( set -o pipefail; "$@" 2>&1 | tee "$log" | fmt ); then status=pass; else status=fail; FAILED+=("$name"); fi
  end=$(date +%s)
  record "$name" "$status" "$log" "$((end - start))"
  echo "=== $name: $status ($((end - start))s)"
}

# The error lines of a log, deduplicated, at most $2 lines (default 60).
error_lines() {
  grep -hE 'error:|: error |failed|Fatal error|Test Suite .* failed|\*\* (BUILD|TEST) FAILED' "$1" 2>/dev/null \
    | grep -vE '^\s*$' | sort -u | head -"${2:-60}"
}

begin_run() {
  mkdir -p "$RUN_DIR"
  FAILED=()
  {
    echo "# mac-build run $(basename "$RUN_DIR")"
    echo
    echo "Commit \`$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null)\` on \`$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)\`, $(xcodebuild -version 2>/dev/null | tr '\n' ' '), simulator \"$(pick_sim)\"."
    echo
    echo "| Step | Result | Time | Log |"
    echo "|---|---|---|---|"
  } > "$RUN_DIR/summary.md"
  echo "Run folder: $RUN_DIR"
}

end_run() {
  {
    echo
    if [ "${#FAILED[@]}" = "0" ]; then
      echo "**All steps passed.**"
    else
      echo "**Failed:** ${FAILED[*]}"
      for f in "${FAILED[@]}"; do
        echo; echo "## $f"; echo; echo '```'
        error_lines "$RUN_DIR/$f.log" 40
        echo '```'
      done
    fi
  } >> "$RUN_DIR/summary.md"
  echo
  cat "$RUN_DIR/summary.md"
  [ "${#FAILED[@]}" = "0" ]
}
