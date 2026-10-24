#!/bin/bash
# Build or test one package, or the app, the way CI does. The unit of the fix loop.
#
# Usage: .claude/skills/mac-build/scripts/test-package.sh <TrapCore|TrapData|TrapWeather|TrapDesign|TrapPlatform|ShotTimer|TrapReports|TrapApp|app|ui> [--build-only] [--filter <TestClass/testName>] [--release]
#   SIM="iPhone 17 Pro" to choose the simulator. --release tests the Release configuration (the detector regression
#   set before an upload, /mac-release). 'ui' runs TrapShooterProUITests through the app scheme.
# Prints the formatted output, then the deduplicated error lines, and exits with xcodebuild's / swift's status.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

TARGET="${1:?package name, 'app' or 'ui'}"; shift
BUILD_ONLY=0; FILTER=""; CONFIG=()
while [ $# -gt 0 ]; do
  case "$1" in
    --build-only) BUILD_ONLY=1; shift ;;
    --filter) FILTER="$2"; shift 2 ;;
    --release) CONFIG=(-configuration Release); shift ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done

SIM_NAME=$(pick_sim)
DEST="platform=iOS Simulator,name=$SIM_NAME"
begin_run

case "$TARGET" in
  TrapCore|TrapData|TrapWeather)
    if [ "$BUILD_ONLY" = "1" ]; then
      run_step "swift-build-$TARGET" swift build --package-path "Packages/$TARGET"
    elif [ -n "$FILTER" ]; then
      run_step "swift-test-$TARGET" swift test --package-path "Packages/$TARGET" --filter "$FILTER"
    else
      run_step "swift-test-$TARGET" swift test --package-path "Packages/$TARGET"
    fi ;;
  TrapDesign)
    design_build() { (cd Packages/TrapDesign && xcodebuild -scheme TrapDesign -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build); }
    run_step design-build design_build ;;
  TrapPlatform|ShotTimer|TrapReports|TrapApp)
    action=test; [ "$BUILD_ONLY" = "1" ] && action=build
    pkg() {
      local args=(-scheme "$TARGET" -destination "$DEST" -derivedDataPath "$DERIVED" ${CONFIG[@]+"${CONFIG[@]}"})
      [ "$action" = "test" ] && args+=(-resultBundlePath "$RUN_DIR/$TARGET.xcresult")
      [ -n "$FILTER" ] && args+=(-only-testing:"${TARGET}Tests/$FILTER")
      (cd "Packages/$TARGET" && xcodebuild "${args[@]}" "$action")
    }
    run_step "sim-$action-$TARGET" pkg ;;
  app)
    run_step app-build xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro \
      -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" ${CONFIG[@]+"${CONFIG[@]}"} CODE_SIGNING_ALLOWED=NO build ;;
  ui)
    ui() {
      local args=(-project TrapShooterPro.xcodeproj -scheme TrapShooterPro -destination "$DEST" -derivedDataPath "$DERIVED"
                  -resultBundlePath "$RUN_DIR/UITests.xcresult" CODE_SIGNING_ALLOWED=NO)
      if [ -n "$FILTER" ]; then args+=(-only-testing:"TrapShooterProUITests/$FILTER"); else args+=(-only-testing:TrapShooterProUITests); fi
      xcodebuild "${args[@]}" test
    }
    run_step ui-test ui ;;
  *) echo "unknown target $TARGET" >&2; exit 2 ;;
esac

end_run
