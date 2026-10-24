---
name: mac-device
description: Run TrapShooterPro on the owner's real iPhone from the Mac and work through the eighteen-row device checklist that the simulator cannot cover (DJI Mic Mini 2 receiver recognised and preferred, port name confirmed, plug and unplug, phone call interruption, Low Power Mode, timing readout, one-hour battery, 2,000-round list speed, backup → reinstall → restore, kill-and-resume, performance budgets, unfinished-round reminder, Low Data Mode weather policy, VoiceOver labels, scorecard PDF text selection). Use when asked to "test on the iPhone", "check the DJI receiver", "run the device checks", "verify timing on device", or when a progress.md item is marked ⏳ iPhone. Requires a Mac, a cable and the owner present with the receiver.
---

# Device checks on the owner's iPhone

The simulator has no microphone and no audio routes. Everything about the timer's real behaviour is decided here,
with the shooter holding the phone. You drive the build and the logs; the owner does the physical steps. Each check
is a row in the session record. Only a passing row flips a `⏳ iPhone` line in `docs/progress.md` to ✅.

**Read first:** `CLAUDE.md` rule 1 (reference receiver), `docs/progress.md` (which rows are ⏳ iPhone / ⏳ iPhone + DJI),
`docs/performance.md` (budgets), `Packages/ShotTimer/Sources/ShotTimer/TimerTypes.swift` (`ReferenceReceiver`,
`AudioDiagnostics.line`), `docs/debugging.md` (how to read `TrapLog` on a device).

## Setup (once per session)

1. `bash .claude/skills/mac-build/scripts/preflight.sh` must show a signing identity; otherwise the owner signs in
   under Xcode → Settings → Accounts first.
2. Cable the iPhone, trust the Mac on the phone, enable Developer Mode (Settings → Privacy & Security).
3. List it: `xcrun xctrace list devices` or `xcrun devicectl list devices`. Note the identifier.
4. Build and install a Debug build:
   ```bash
   xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro -destination 'generic/platform=iOS' \
     -derivedDataPath build/mac/DerivedData -allowProvisioningUpdates build
   xcrun devicectl device install app --device <id> build/mac/DerivedData/Build/Products/Debug-iphoneos/TrapShooterPro.app
   ```
   If XcodeBuildMCP is configured with the device workflow, prefer its device build/install/launch tools.
5. Stream logs while testing, in the background, filtered to our subsystem:
   ```bash
   xcrun devicectl device process launch --device <id> --console com.mtajudeen.trapshooterpro
   ```
   or Console.app on the Mac with the phone selected and the filter `subsystem:com.mtajudeen.trapshooterpro`.

## The checklist

Work through the rows in this order; stop and fix (then rebuild) when a row fails before continuing. Tell the owner
exactly what to do for each row in one sentence; you read the log and the screen for the result.

| # | Check | Owner does | You confirm in log / screen | Progress.md row |
|---|---|---|---|---|
| 1 | Phone mic baseline | open Timer, tap Start, say "pull", clap | level meter moves, `timer.start` signpost < 300 ms, no error | Device checks |
| 2 | DJI port name | plug the DJI Mic Mini 2 receiver in, open Timer | `inputs` event lists a port whose name contains "DJI"; write the exact string into the session record | Port name of the DJI receiver confirmed |
| 3 | Preferred under System default | leave input on System default with the DJI plugged in | the audio check line (`AudioDiagnostics.line`) names the DJI; detector takes it | DJI as reference receiver |
| 4 | Explicit pick wins | choose the phone mic in Settings while the DJI is plugged in | phone mic stays selected; no silent switch back | DJI as reference receiver |
| 5 | Plug / unplug while timing | start the timer, unplug the receiver, plug it back | `route` then `restarted` events; `timer.restart` < 500 ms; timing resumes at 0.000 | Device checks |
| 6 | Phone call interruption | have someone call the phone while timing | timer stops cleanly, `error`/state line shown as text (not an alert), restart works | Device checks |
| 7 | Background | press Home while timing | timer stops (ADR-010, no background audio); returning shows a stopped state | Device checks |
| 8 | Low Power Mode | enable Low Power Mode, start the timer | level meter drops to 5 Hz (`PowerMonitor.levelMeterHz`), timing still correct | Device checks |
| 9 | Timing sanity | call "pull", fire a dry shot (or clap) at a known interval against a stopwatch, five times | readouts within ±0.02 s of the stopwatch; first/target events in log | Device checks |
| 10 | One-hour battery | run the timer for 60 min with the DJI plugged in, screen on, then Settings → Battery | < 10 % used on an iPhone 15 class device | 1 h < 10 % battery |
| 11 | 2,000 rounds list | import a generated backup of 2,000 rounds (you write it with a short script in the TrapData backup JSON layout, `docs/testing.md`; there is no in-app generator), open Rounds | first screen < 50 ms (`fetchSummaries` signpost); scrolling smooth | 2,000 rounds first list screen |
| 12 | Backup → reinstall → restore | export a backup, delete the app, reinstall, import the backup | round count and a spot-checked round identical | Backup → reinstall → restore |
| 13 | Kill and resume mid-round | record 7 targets, swipe-kill the app, relaunch | round resumes at target 8 with the same station and entries | Kill-and-resume on device |
| 14 | Performance budgets (`docs/performance.md`) | cold-launch the app five times (swipe-kill between), enter three targets, start the timer once | from Instruments (App Launch, os_signpost) or the `performance` signpost category in Console: launch to Record < 400 ms, `data.save` < 10 ms on the main thread, `timer.start` < 300 ms; Allocations steady state while timing < 60 MB | Performance gates on device |
| 15 | Unfinished-round reminder | Settings → turn on "Remind me of an unfinished round" (permission prompt appears now, never at launch), record 3 targets, leave the app, wait 20 min | the local notification arrives once; tapping it opens the round; declining permission leaves a line of text in Settings, not an alert | Lifecycle, power, network, reminder, MetricKit wired |
| 16 | Low Data Mode and weather | enable Low Data Mode on the phone's network, start a new round with weather auto-fill on; then tap the manual weather button; then airplane mode and tap again | no automatic fetch (`NetworkMonitor.isConstrained`, `allowsAutomaticFetch` false); the manual tap fetches; offline shows the "no weather" state as text, the round continues | Lifecycle, power, network, reminder, MetricKit wired |
| 17 | VoiceOver | triple-click the side button, swipe through Record and Timer | every target button reads station, target and direction ("Station 3, target 11, left"), result buttons read "Hit first barrel" etc., the NO TARGET bar and timer Start have labels; nothing reads as "button" alone | iPhone tabs, iPad split, keyboard, VoiceOver, Dynamic Type |
| 18 | Scorecard PDF text | export a scorecard as PDF, open it in Files, long-press the shooter's name | text selects and copies (vector PDF, not a bitmap); the file name has no stray characters; the temp file is gone from the app's tmp after sharing | Exports through `ExporterFactory` and the share sheet |

Rows 10, 13 and 15 take real time; start row 10 first, start row 15's 20-minute wait right after, and do rows 11,
12, 14, 16–18 meanwhile only if a second phone is available, otherwise do them last. Row 14 wants the phone cabled
with Instruments on the Mac; the signposts are in the `performance` category of subsystem
`com.mtajudeen.trapshooterpro`.

## Recording results

Dispatch **progress-scribe** with the table of rows, pass/fail, the evidence (log line, screenshot path under
`build/mac/device-<date>/`, measured number) and the device model + iOS version. It writes
`docs/mac-sessions/<date>-device.md` and flips the matching `docs/progress.md` rows. The exact DJI port name goes
into `docs/mac-sessions/<date>-device.md` and into a comment next to `ReferenceReceiver` in `TimerTypes.swift` so the
match rule can be tightened later with evidence.

## When a row fails

- Receiver not listed or not preferred: the fix belongs in `TimerSession` / `TimerTypes` (rule 1), never in
  `AudioDetector.swift`. Dispatch **swift-builder** with the log lines and the row.
- Timing off by more than 0.02 s consistently: do not touch the detector. Record the numbers, the receiver, the
  phone model, and stop; the detector regression set (⏳ owner recordings) is the tool for that, not a live tweak.
- Battery, launch, save or list-speed over budget: record the measurement and the Instruments trace path; fixing is a
  separate task.
- A missing VoiceOver label or a bitmap PDF is a code finding in `TrapApp` or `TrapReports`; dispatch **swift-builder**
  with the row and the screen or exporter name. The fix must keep the design tokens and the PDF exporter's vector path.
