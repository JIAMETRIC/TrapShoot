# TrapShooterPro for iPhone and iPad

**This repository is moving from the 7.0.7 hybrid app (web page in a WKWebView) to a 100% native SwiftUI, local-first app.**
The plan is in [`docs/native-plan.md`](docs/native-plan.md). The first native package is [`Packages/TrapCore`](Packages/TrapCore)
(round model, Olympic Trap rules, schemes, break distance, CSV, analysis) with golden tests against the JavaScript original,
and [`Packages/TrapDesign`](Packages/TrapDesign) holds the black‑and‑white design system (see [`docs/design-system.md`](docs/design-system.md)).
The notes below describe the 7.0.7 baseline, which still builds as before.

---

# TRAP SHOOTER PRO for iPhone, Ver 7.0.7

A ready-made Xcode project. Open it, pick your team, press Run.

It installs as a **separate app** called **Shooter Pro**. TRAP LOGGER and Trap Shot Timer stay on the phone as they are.

**Ver 7.0.1 timer fix.** The shot timer now runs the same Swift detector as the Trap Shot Timer app, on the audio thread. The page only shows the results. The audio session is set once when the timer starts and is never changed while timing runs.

**Ver 7.0.2 round audio.** Timer settings > **Round audio > Record for checking** saves each Start-to-Stop session as an .m4a file (about 1 MB per minute). Tap **Share last recording** to send it. Files also appear in the Files app under **On My iPhone > Shooter Pro > Recordings**.

**Ver 7.0.3 detector v3.** Validated on 9 range videos (Yugan, Khalid, Pittu): every 1st shot within 7 ms of the reference, 2nd shots correct, no false 2nd shots.
- A shot is confirmed by its sound above 3 kHz (gunshots 20 to 60% of energy, voices under 1%). Real shots are no longer rejected as loud voices.
- The echo of a shot no longer counts as a 2nd shot.
- Call onset is traced back to the background level. The fixed timing offset fell from about 5 ms to under 1 ms.

**Ver 7.0.4 range flow and DJI fix.**
- Timing follows the target on screen: call and shots, then direction and result, then the timer arms for the next target and resets to 0.000. Shots fired while you enter a result are ignored.
- Skip = no time for this target. Re-time T# = time the selected target again.
- External receivers: a fresh audio engine after any hardware change, a watchdog that restarts audio if nothing arrives for 1.5 s (up to 3 times), the louder of 2 channels is used, and System default picks a plugged-in receiver over the phone mic.
- Timer tab shows an audio check line: input, type, sample rate, channels, and whether audio is arriving.

**Ver 7.0.5 break distance.**
- New **Break m** column after 2nd shot s, in the targets list, scorecard image, PDF and CSV.
- Hits only. A 1st shot time alone gives the 1st shot break. 1st and 2nd shot times give the 2nd shot break. A lost target has no break.
- Model: your Trap Trajectory clay path (scheme angle and height, station, machine position) plus the shot flight time with air drag.
- Timer tab > **Break distance**: release delay **50 ms**, clay speed **28 m/s**, shot speed V1 **415 m/s** (RC4 Champion Excellence 24 g), shot size **7.5**.
- CSV adds `break_m`, `break_shot`, `release_delay_ms`, `shot_v1_ms`, `shot_size`.

**Ver 7.0.6 call onset fix (detector v3.1).**
- The timer now starts at the true start of your voice. Before, ordinary background noise before a call was sometimes counted as part of the call, so some times read up to 55 ms long.
- Rule: the trace back from the call stops 6 dB above the typical background of the last 0.3 s, not only 6 dB above its quietest dips.
- Checked on your 18 Oct mic test (collar mic + phone 5 m away): all 10 calls within 3 ms of the true voice start (7.0.5: up to 55 ms). A phone 5 m away hears the call about 19 ms later than the collar mic.
- Release delay note: the 17 Oct videos show the release lamp going off 65 to 95 ms after the call. Best estimate call to clay at the trench front: about 170 ms until measured. Set it on the Timer tab, Break distance.

**Ver 7.0.7 NO TARGET.**
- New full-width **NO TARGET** bar under the Result row.
- Use it when the clay does not come, comes out broken, or you want the same target again in training.
- The target keeps its number and station. Direction, result, 1st and 2nd shot times clear. The timer drops what it heard (also between the 1st and 2nd shot) and listens for a new call. Readout back to 0.000.
- **Undo** on the timer bar restores the target. Result already entered and the app moved on: tap **Previous**, then **NO TARGET**.
- Each press is counted: "No target ×n" next to the station, CSV column `no_target`.
- Timer readout no longer crowds on phone widths.

## If the DJI badge shows No signal

1. Read the **Audio in** line on the Timer tab.
2. **NO AUDIO**: unplug and replug the receiver, switch the transmitter off and on, then Stop and Start timer.
3. **receiving** but the badge stays red: the receiver sends silence. Check the transmitter is paired (receiver screen) and not muted.
4. Send a screenshot of the Timer tab if it persists.

**Status: not compiled here.** It was built on a computer without Xcode. The Swift files pass a syntax check and the page-to-app messages were tested in a browser simulation. If Xcode shows a red error, send a screenshot.

## What you need

- A Mac with **Xcode 15 or newer**.
- Your **iPhone 17 Pro Max** and its USB-C cable.
- Your free Apple ID (Personal Team), the same one you used for Trap Shot Timer.

## Install

1. Unzip **TrapShooterPro-iPhone.zip**.
2. Double-click **TrapShooterPro.xcodeproj**.
3. Click **TrapShooterPro** at the top of the left list. Open **Signing & Capabilities**.
4. **Team:** pick **Mohammad Tajudeen (Personal Team)**.
5. Leave the **Bundle Identifier** as `com.mtajudeen.trapshooterpro`. If Xcode says it is taken, add a letter at the end, for example `com.mtajudeen.trapshooterpro2`.
6. Connect the iPhone. Pick it in the device menu at the top of Xcode.
7. Press **Run** (▶).
8. First time only, on the iPhone: **Settings > General > VPN & Device Management.** Tap your Apple ID. Tap **Trust**.
9. Open **Shooter Pro**. Allow the microphone when asked. Allow location if you want the weather filled in.

Free Apple ID installs last **7 days**. Connect the iPhone and press **Run** again to renew. Your rounds stay.

## How the iPhone app differs from the web app

| Part | iPhone app |
|---|---|
| Microphone | Runs in the app, with no automatic gain or noise processing |
| DJI Mic Mini 2 receiver | Picked up as soon as it is plugged in. Badge turns green. |
| Receiver unplugged | Timing stops and the app says so |
| Phone call or Siri | Timing stops. Tap Start shot timer again. |
| Screen | Stays on while the timer runs |
| CSV, image, PDF | Open the share sheet: save to Files, AirDrop or mail |
| Weather | Uses the iPhone's location once per round |
| Account and rounds | Same Supabase account as the web app |

## Install the fix over the old build

1. Delete the old TrapShooterPro folder on the Mac.
2. Unzip the new **TrapShooterPro-iPhone.zip**. Open **TrapShooterPro.xcodeproj**.
3. Pick your Team again in **Signing & Capabilities**. Keep the same Bundle Identifier.
4. Press **Run**. Your rounds and settings stay.

## Update the app later

The round recorder lives in the **Web** folder. To update it, replace `Web/index.html` with the new file and press **Run**. No Swift changes are needed.

## Files

| File | Job |
|---|---|
| `TrapShooterProApp.swift` | App start |
| `ContentView.swift` | Shows the page. Handles save, alerts, links and location messages. |
| `AudioDetector.swift` | Shot detector v3. Runs on the audio thread. Follows the channel that carries sound. |
| `MicBridge.swift` | Starts and stops the mic, restarts it after hardware changes or silence, sends results and the audio check to the page |
| `RoundRecorder.swift` | Saves round audio as .m4a with a settings .json |
| `LocationFetcher.swift` | One-off location for the weather |
| `Web/` | TRAP SHOOTER PRO page, `config.js`, `supabase.js`, icons |
| `Assets.xcassets` | App icon |
