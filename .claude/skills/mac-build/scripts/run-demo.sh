#!/bin/bash
# Build the app for the simulator, install it, launch it in demo mode (-demo: sample rounds, no microphone) and
# either leave it running on the chosen section or take the full screenshot set (every section, light and dark,
# iPhone and iPad) through Scripts/screenshots.sh.
#
# Usage: .claude/skills/mac-build/scripts/run-demo.sh [--section record|timer|rounds|analysis|schemes|settings]
#                                                    [--dark] [--screenshots <out folder>] [--no-build]
#   SIM="iPhone 17 Pro" to choose the simulator.
# Prints the path of the built .app, the simulator UDID and, after a launch, 20 s of the app's log so a crash shows.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

SECTION=record; LOOK=light; SHOTS=""; BUILD=1
while [ $# -gt 0 ]; do
  case "$1" in
    --section) SECTION="$2"; shift 2 ;;
    --dark) LOOK=dark; shift ;;
    --screenshots) SHOTS="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done

BUNDLE=com.mtajudeen.trapshooterpro
SIM_NAME=$(pick_sim)
begin_run

if [ "$BUILD" = "1" ]; then
  run_step app-build xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro \
    -destination "platform=iOS Simulator,name=$SIM_NAME" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
  [ "${#FAILED[@]}" = "0" ] || { end_run; exit 1; }
fi

APP=$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'TrapShooterPro.app' -path '*iphonesimulator*' | head -1)
[ -n "$APP" ] || { echo "no TrapShooterPro.app under $DERIVED/Build/Products; build first" >&2; exit 1; }
echo "APP=$APP"

if [ -n "$SHOTS" ]; then
  run_step screenshots Scripts/screenshots.sh "$APP" "$SHOTS"
  echo "Screenshots and an index page: $SHOTS/README.md"
  end_run; exit $?
fi

UDID=$(xcrun simctl list devices available | grep -m1 -F "$SIM_NAME (" | grep -oE '[0-9A-F-]{36}')
[ -n "$UDID" ] || { echo "simulator \"$SIM_NAME\" not found" >&2; exit 1; }
echo "UDID=$UDID"

launch() {
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl ui "$UDID" appearance "$LOOK"
  xcrun simctl install "$UDID" "$APP"
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  xcrun simctl launch --console-pty "$UDID" "$BUNDLE" -demo -state.section "$SECTION" &
  local pid=$!
  sleep 20
  kill "$pid" 2>/dev/null || true
  # A crash leaves a report; name it so the caller can read it.
  local crash
  crash=$(ls -t ~/Library/Logs/DiagnosticReports/TrapShooterPro*.ips 2>/dev/null | head -1)
  if [ -n "$crash" ] && [ "$(( $(date +%s) - $(stat -f %m "$crash") ))" -lt 60 ]; then
    echo "CRASH REPORT: $crash"; return 1
  fi
  xcrun simctl io "$UDID" screenshot --type=png "$RUN_DIR/$SECTION-$LOOK.png" >/dev/null && echo "SCREENSHOT=$RUN_DIR/$SECTION-$LOOK.png"
}
run_step "launch-$SECTION-$LOOK" launch
end_run
