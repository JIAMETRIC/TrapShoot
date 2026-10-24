#!/bin/bash
# Readiness check for a Claude Code build session on a Mac.
# Prints one line per check (OK / WARN / FAIL) and exits 1 if any check FAILed.
# Usage: .claude/skills/mac-build/scripts/preflight.sh
set -uo pipefail
cd "$(dirname "$0")/../../../.."

fail=0
ok()   { printf 'OK    %-28s %s\n' "$1" "$2"; }
warn() { printf 'WARN  %-28s %s\n' "$1" "$2"; }
bad()  { printf 'FAIL  %-28s %s\n' "$1" "$2"; fail=1; }

# 1. This must be a Mac.
if [ "$(uname -s)" != "Darwin" ]; then
  bad "platform" "$(uname -s): Xcode only runs on macOS. Edit and reason here; build on the Mac."
  exit 1
fi
ok "platform" "macOS $(sw_vers -productVersion 2>/dev/null || echo '?') on $(uname -m)"

# 2. Full Xcode selected, not the Command Line Tools.
dev_dir=$(xcode-select -p 2>/dev/null || true)
case "$dev_dir" in
  *Xcode*.app*) ok "xcode-select" "$dev_dir" ;;
  "")           bad "xcode-select" "no developer directory; install Xcode and run: sudo xcode-select -s /Applications/Xcode.app" ;;
  *)            bad "xcode-select" "$dev_dir points at the Command Line Tools; run: sudo xcode-select -s /Applications/Xcode.app" ;;
esac

if xcodebuild -version >/dev/null 2>&1; then
  ver=$(xcodebuild -version | tr '\n' ' ')
  major=$(xcodebuild -version | awk 'NR==1{print int($2)}')
  if [ "${major:-0}" -ge 16 ]; then ok "xcodebuild" "$ver"; else bad "xcodebuild" "$ver (need Xcode 16 or newer for iOS 17 + Swift 5.9 packages)"; fi
else
  bad "xcodebuild" "not runnable; open Xcode once to finish installing components"
fi

# 3. License and first-run components.
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then ok "xcode first launch" "components installed"; else warn "xcode first launch" "run: sudo xcodebuild -runFirstLaunch (or open Xcode once)"; fi

# 4. Swift toolchain.
if command -v swift >/dev/null 2>&1; then ok "swift" "$(swift --version 2>&1 | head -1)"; else bad "swift" "no swift on PATH"; fi

# 5. Simulators: one iPhone and one iPad available.
if xcrun simctl list devices available >/dev/null 2>&1; then
  iphone=$(xcrun simctl list devices available | grep -m1 -E 'iPhone' | sed 's/^ *//')
  ipad=$(xcrun simctl list devices available | grep -m1 -E 'iPad' | sed 's/^ *//')
  [ -n "$iphone" ] && ok "simulator iPhone" "$iphone" || bad "simulator iPhone" "none; Xcode > Settings > Components, download an iOS 17+ runtime"
  [ -n "$ipad" ]   && ok "simulator iPad" "$ipad"     || warn "simulator iPad" "none; iPad screenshots will be skipped"
else
  bad "simctl" "xcrun simctl failed"
fi

# 6. Xcode MCP bridge (Xcode 26.3+) and whether Xcode is running with the project open.
if xcrun --find mcpbridge >/dev/null 2>&1; then
  ok "mcpbridge" "$(xcrun --find mcpbridge)"
  if pgrep -x Xcode >/dev/null 2>&1; then ok "Xcode running" "yes (the bridge needs the project open in it)"; else warn "Xcode running" "no; run: open TrapShooterPro.xcodeproj  (needed only for the Xcode bridge and previews)"; fi
else
  warn "mcpbridge" "not found; Xcode 26.3+ needed for live diagnostics and RenderPreview. XcodeBuildMCP still works."
fi

# 7. Node for npx (XcodeBuildMCP) and the golden fixture generator.
if command -v node >/dev/null 2>&1; then ok "node" "$(node --version)"; else bad "node" "brew install node (XcodeBuildMCP and Tools/golden/generate.js need it)"; fi
if command -v npx  >/dev/null 2>&1; then ok "npx" "present"; else bad "npx" "comes with node"; fi

# 8. Pretty printers are optional.
if command -v xcbeautify >/dev/null 2>&1; then ok "xcbeautify" "present"; elif command -v xcpretty >/dev/null 2>&1; then ok "xcpretty" "present"; else warn "log formatter" "none; raw xcodebuild logs (brew install xcbeautify for shorter output)"; fi

# 9. Repository state.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git rev-parse --abbrev-ref HEAD)
  dirty=$(git status --porcelain | wc -l | tr -d ' ')
  [ "$dirty" = "0" ] && ok "git" "branch $branch, clean" || warn "git" "branch $branch, $dirty changed file(s); commit or stash before a build you want to trust"
  if git fetch --dry-run origin >/dev/null 2>&1; then
    behind=$(git rev-list --count HEAD..origin/"$branch" 2>/dev/null || echo 0)
    [ "$behind" = "0" ] && ok "git remote" "up to date with origin/$branch" || warn "git remote" "$behind commit(s) behind origin/$branch; git pull first"
  else
    warn "git remote" "could not reach origin (offline?)"
  fi
else
  bad "git" "not inside the repository"
fi

# 10. Project and schemes.
if [ -d TrapShooterPro.xcodeproj ]; then
  if xcodebuild -list -project TrapShooterPro.xcodeproj 2>/dev/null | grep -q 'TrapShooterPro'; then ok "scheme" "TrapShooterPro"; else bad "scheme" "TrapShooterPro scheme missing from the project"; fi
else
  bad "project" "TrapShooterPro.xcodeproj not found; run from the repository root"
fi
for p in TrapCore TrapData TrapWeather TrapDesign TrapPlatform ShotTimer TrapReports TrapApp; do
  [ -f "Packages/$p/Package.swift" ] || bad "package $p" "Packages/$p/Package.swift missing"
done

# 11. Disk space: a full build with DerivedData wants ~10 GB free.
free_gb=$(df -g . | awk 'NR==2{print $4}')
if [ "${free_gb:-0}" -ge 10 ]; then ok "disk" "${free_gb} GB free"; else warn "disk" "${free_gb} GB free; builds may fail below ~10 GB"; fi

# 12. Developer account (only for device runs and archives).
if security find-identity -v -p codesigning 2>/dev/null | grep -q 'Apple Development\|Apple Distribution'; then
  ok "signing identity" "found (device runs and archives possible)"
else
  warn "signing identity" "none; simulator work is fine, device runs and TestFlight need Xcode > Settings > Accounts"
fi

echo
if [ "$fail" = "0" ]; then echo "READY: no FAIL lines. WARN lines limit what the session can verify."; else echo "NOT READY: fix the FAIL lines above, then rerun."; fi
exit $fail
