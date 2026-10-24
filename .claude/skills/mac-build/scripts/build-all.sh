#!/bin/bash
# The CI pipeline (.github/workflows/ci.yml) run locally on a Mac, every step, continuing past failures so one run
# shows every error. Logs and a summary land in build/mac/<timestamp>/.
#
# Usage: .claude/skills/mac-build/scripts/build-all.sh [--only pure|app|sim|design|ui|fixtures] [--skip-fixtures]
#   SIM="iPhone 17 Pro" to choose the simulator; RUN_DIR=... to choose the output folder.
# Exit code: 0 when every step passed.
set -uo pipefail
source "$(dirname "$0")/lib.sh"
cd "$REPO_ROOT"

ONLY=""; SKIP_FIXTURES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --skip-fixtures) SKIP_FIXTURES=1; shift ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

SIM_NAME=$(pick_sim)
DEST="platform=iOS Simulator,name=$SIM_NAME"
begin_run

# 1. Golden fixtures must still match the JavaScript reference (never regenerate to make a test pass).
if want fixtures && [ "$SKIP_FIXTURES" = "0" ]; then
  fixtures_check() {
    node Tools/golden/generate.js Tools/golden/reference/index-7.0.7.html Packages/TrapCore/Tests/TrapCoreTests/Fixtures \
      && git diff --exit-code -- Packages/TrapCore/Tests/TrapCoreTests/Fixtures
  }
  run_step fixtures-current fixtures_check
fi

# 2. Pure packages: swift test on the host (Foundation / SwiftData, no UIKit).
if want pure; then
  run_step swift-test-TrapCore    swift test --package-path Packages/TrapCore --parallel
  run_step swift-test-TrapData    swift test --package-path Packages/TrapData
  run_step swift-test-TrapWeather swift test --package-path Packages/TrapWeather
fi

# 3. The app target for the simulator (the only product; links TrapApp).
if want app; then
  run_step app-build xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build
fi

# 4. iOS-only packages: tests in the simulator.
if want sim; then
  for p in TrapPlatform ShotTimer TrapReports TrapApp; do
    pkg_test() { (cd "Packages/$1" && xcodebuild -scheme "$1" -destination "$DEST" -derivedDataPath "$DERIVED" \
      -resultBundlePath "$RUN_DIR/$1.xcresult" test); }
    run_step "sim-test-$p" pkg_test "$p"
  done
fi

# 5. Design system builds for iOS.
if want design; then
  design_build() { (cd Packages/TrapDesign && xcodebuild -scheme TrapDesign -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build); }
  run_step design-build design_build
fi

# 6. The range flow on screen, through the scripted demo timer (TrapShooterProUITests, docs/testing.md).
if want ui; then
  run_step ui-test xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro -destination "$DEST" \
    -derivedDataPath "$DERIVED" -resultBundlePath "$RUN_DIR/UITests.xcresult" -only-testing:TrapShooterProUITests \
    CODE_SIGNING_ALLOWED=NO test
fi

end_run
