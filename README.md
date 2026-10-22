# TrapShoot — TrapShooterPro for iPhone and iPad

A native SwiftUI app for Olympic Trap shooters: a call‑to‑shot timer that listens through the microphone or a
**DJI Mic Mini 2** receiver, a 25‑target round recorder, break distance, analysis and exports.
**Local‑first: no account, no server.** The only network call is the optional weather fill. iOS 17+, iPhone and iPad.

| | |
|---|---|
| Progress by phase | [`docs/progress.md`](docs/progress.md) |
| Plan and exit gates | [`docs/phases/README.md`](docs/phases/README.md) |
| Architecture and decisions (ADR‑001…017) | [`docs/architecture.md`](docs/architecture.md) |
| Engineering, testing, security, performance | [`docs/engineering.md`](docs/engineering.md) |
| Design system | [`docs/design-system.md`](docs/design-system.md) |
| Building without a local Mac (CI) | [`docs/build-options.md`](docs/build-options.md) |
| Publishing | [`docs/app-store.md`](docs/app-store.md) |
| Rules for Claude sessions | [`CLAUDE.md`](CLAUDE.md) |

## Layout

| Path | What |
|---|---|
| `TrapShooterPro/` | the app target: `@main` entry, icon, privacy manifest |
| `Packages/TrapApp` | screens and view models: Record, Timer, Rounds, Analysis, Schemes, Settings |
| `Packages/TrapCore` | rules, schemes, round document, CSV, break distance, analysis (golden‑tested) |
| `Packages/ShotTimer` | the validated 7.0.7 detector and recorder, `TimerSession` |
| `Packages/TrapData` | SwiftData store, summaries, backup, import of 7.x data |
| `Packages/TrapReports` | scorecard PNG and PDF, CSV and backup exporters |
| `Packages/TrapWeather` | Open‑Meteo weather fill, one‑shot location |
| `Packages/TrapPlatform` | lifecycle, power, network, notifications, storage, diagnostics |
| `Packages/TrapDesign` | black‑and‑white design system |
| `Tools/golden/` | golden fixture generator and the frozen 7.0.7 page it reads |

Every push to `main` is compiled and tested on GitHub's macOS runners (`.github/workflows/ci.yml`).

## Run it on your iPhone

1. On a Mac with Xcode 16 or newer, open `TrapShooterPro.xcodeproj`.
2. **Signing & Capabilities** → Team: your Apple ID. Keep the bundle id `com.mtajudeen.trapshooterpro`.
3. Connect the iPhone, pick it at the top of Xcode, press **Run**.
4. Open **TrapShoot**. The microphone is asked the first time you tap **Start timer**; location only when you tap **Weather**.

Moving from 7.x: export your rounds from the old app or the Supabase table as JSON, then **Settings → Data → Restore or
import a backup**. Rounds you already have are never replaced.

## If the audio check line says NO AUDIO

1. Read the **Audio in** line on the Timer tab: it names the **DJI Mic Mini 2 receiver** when that is the input.
2. **NO AUDIO**: unplug and replug the receiver, switch the transmitter off and on, then Stop and Start timer.
3. **receiving** but no calls are heard: the transmitter is muted or not paired (check the receiver's screen).
4. Still stuck: **Settings → About → Send diagnostics** and mail the file.

## The range flow (kept from 7.0.x)

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
