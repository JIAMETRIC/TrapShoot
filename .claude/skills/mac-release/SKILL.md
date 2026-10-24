---
name: mac-release
description: Archive TrapShooterPro on the Mac, upload it to TestFlight, tag the build and prepare the App Store submission material (screenshots, privacy answers, review notes). Use when asked to "archive", "upload to TestFlight", "make a build for the testers", "tag the beta", "prepare the App Store submission", or when progress.md Phase 9 items are the next work. Needs a Mac signed in to the Apple Developer account and the user's explicit go-ahead for every upload.
---

# Release from the Mac

Archiving and uploading are outward-facing and hard to undo (a build number can never be reused). Every step that
signs, uploads or tags is done only after the user says yes to that specific step in this session. Preparing files,
screenshots and text needs no permission.

**Read first:** `docs/app-store.md` (order of work, privacy answers, review notes, quality gates), `ExportOptions.plist`,
`Scripts/archive.sh`, `.github/workflows/release.yml`, `docs/progress.md` Phase 9, `docs/git-workflow.md` (tags).

## Gate: nothing ships that `/mac-build` did not pass today

1. The last `build/mac/<ts>/summary.md` of today says all steps passed on the current commit, and the working tree
   is clean (`git status`). If not, run `/mac-build` first.
1b. The detector regression set on the Release configuration (Phase 8: "run the detector regression set on the
   release build"): `bash .claude/skills/mac-build/scripts/test-package.sh ShotTimer --release`. With no fixtures
   recorded yet the test skips; say so in the record rather than calling it passed.
2. `docs/progress.md` has no 🔨 items in the phase being shipped.
3. `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the project are what the user wants:
   ```bash
   xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro -showBuildSettings 2>/dev/null | grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION'
   ```
   The build number must be higher than the last one App Store Connect accepted. Ask before changing either.

## Steps

### 1. Archive and upload (asks first)

Show the user: version, build number, commit, team id source. On yes:

```bash
TEAM_ID=<from Xcode > Settings > Accounts> bash Scripts/archive.sh
```

Run in the background (10–20 min). The script archives Release for `generic/platform=iOS`, exports with
`ExportOptions.plist` (method app-store-connect, upload) and prints "Uploaded." A signing failure means the account or
the App ID in App Store Connect is missing; the fix is in Xcode → Settings → Accounts or at developer.apple.com, not
in the project. Do not add signing settings to the pbxproj to get past it.

### 2. Tag (asks first)

The first upload is `v8.0.0-b1`; later uploads increment `-bN`. Tag the exact commit that was archived:

```bash
git tag -a v8.0.0-b1 -m "TestFlight build 1: <one line of what is in it>"
git push origin v8.0.0-b1
```

### 3. TestFlight

Processing takes 10–30 min in App Store Connect. Internal testing (the owner) needs no review; external testing
(the three shooters named in `docs/app-store.md`) needs the beta review, which the review notes in that document
answer. The "What to test" text comes from the session record of `/mac-build` and `/mac-device`: what changed, what
to try on the range.

### 4. Submission material (no permission needed to prepare)

- Screenshots: `bash .claude/skills/mac-build/scripts/run-demo.sh --screenshots build/mac/release-shots` gives every
  section light and dark on an iPhone and an iPad in demo mode. App Store Connect wants 6.9-inch iPhone and 13-inch
  iPad sizes; `Scripts/screenshots.sh` picks those simulators when present.
- Privacy answers, review notes, listing text: already in `docs/app-store.md`; copy, do not rewrite. If behaviour
  changed (microphone, location use), update that document and `PrivacyInfo.xcprivacy` in the same commit.
- Export compliance: the app uses only Apple's TLS for the optional Open-Meteo call; the answer is "exempt" (standard
  encryption). Say so in the notes.

### 5. Record

Dispatch **progress-scribe**: Phase 9 rows (tag, API key, TestFlight internal/external, submission) with the build
number, upload time and the App Store Connect state. It writes `docs/mac-sessions/<date>-release.md`.

## Never

- Upload or tag without the user's yes in this session, for that build.
- Commit a `.p8` key, a team id in a tracked file, or a provisioning profile. `TEAM_ID` is an environment variable;
  `ExportOptions.plist` keeps the `$(TEAM_ID)` placeholder.
- Bump the build number silently; the number is part of what the user approves.
