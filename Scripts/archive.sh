#!/bin/sh
# Archive TrapShooterPro and upload it to App Store Connect (TestFlight).
# Usage: TEAM_ID=ABCDE12345 Scripts/archive.sh
# Needs: Xcode signed in to the Apple Developer account (Xcode > Settings > Accounts).
set -eu
cd "$(dirname "$0")/.."
: "${TEAM_ID:?Set TEAM_ID to your Apple Developer Team ID}"
OUT=build/archive
mkdir -p "$OUT"
sed "s/\$(TEAM_ID)/$TEAM_ID/" ExportOptions.plist > "$OUT/ExportOptions.plist"
xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$OUT/TrapShooterPro.xcarchive" \
  DEVELOPMENT_TEAM="$TEAM_ID" archive
xcodebuild -exportArchive -archivePath "$OUT/TrapShooterPro.xcarchive" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -exportPath "$OUT/export"
echo "Uploaded. Watch App Store Connect > TestFlight for processing."
