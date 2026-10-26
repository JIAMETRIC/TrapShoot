# TrapShooterPro: autonomous Mac run

Give this file to Claude Desktop (Code tab) with the TrapShooterPro folder open, and say:

> Read MAC-AUTONOMOUS-RUN.md and carry it out. Stop only where it says to stop.

Everything below is the brief. Claude follows it with the skills and agents already in `.claude/`.

---

## 0. What you do on the MacBook (once, then each session)

Once (details in `docs/mac-setup.md`):

1. Install **Xcode 26.3 or newer** from the App Store and open it once.
2. In Terminal:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app
   xcrun --find mcpbridge
   brew install node
   ```
   The last command must print a path.
3. In Xcode: **Settings → Intelligence → Model Context Protocol → Allow external agents to use Xcode tools** (on).
4. Sign in to your Apple Developer account in Xcode → Settings → Accounts. Needed only for Phase 8.

Each session:

1. Get the code:
   ```bash
   git clone https://github.com/JIAMETRIC/TrapShooterPro.git
   cd TrapShooterPro
   git pull
   ```
   If the folder already exists, skip the clone and run only `git pull`.
2. Open `TrapShooterPro.xcodeproj` in Xcode and leave it open. The Xcode bridge needs it.
3. Open the `TrapShooterPro` folder in Claude Desktop (Code tab) and start a new session.
4. Paste the line above.

---

## 1. Ground rules for this run

**Read first, in this order:** `CLAUDE.md`, `docs/phases/README.md`, `docs/progress.md`, `docs/mac-session.md`,
`.claude/skills/mac-build/SKILL.md`, `.claude/skills/mac-build/reference/phase-map.md`.

**You may, without asking:**
- Run the preflight and every `mac-build` stage, in the background where the skill says so.
- Dispatch the agents `mac-preflight`, `swift-builder`, `sim-tester`, `app-verifier`, `design-reviewer`,
  `progress-scribe` and `support-triage` as the skills direct.
- Fix compile errors and failing tests within `CLAUDE.md` rules.
- Write `docs/mac-sessions/<date>.md` and update the `⏳ Mac` rows in `docs/progress.md` from evidence only.
- Make **local** commits, one topic each, imperative subject, body says why (`CLAUDE.md` rule 10).

**You must stop and ask me before:**
- Any `git push`, pull request or merge.
- Any signing, archive, TestFlight or App Store upload (`/mac-release`).
- Any step that needs the iPhone, the DJI Mic Mini 2 receiver, the microphone or me physically present (`/mac-device`).
- Changing `AudioDetector.swift` detection logic, regenerating fixtures in `Packages/TrapCore/Tests/TrapCoreTests/Fixtures`,
  touching `Tools/golden/`, or changing the document v2 JSON or CSV layouts.
- Deleting a failing test (skip it with `XCTSkip` and a reason instead, or fix it).
- Anything that sends data outside the Mac (no network except the optional weather fill).

**Reporting rules:** report test output faithfully. A stage passes only when its `summary.md` says so. Never claim
device behaviour from the simulator. If a step cannot run, say so in the record under **Open**.

---

## 2. The run, in order

### Step A. Preflight (skill `mac-build`, stage 0)

Run `bash .claude/skills/mac-build/scripts/preflight.sh`. Any `FAIL` line: stop, show it, and give me the exact command
from that line. `WARN` lines: note them and continue.

Check `/mcp`. **XcodeBuildMCP** and **xcode** should both be connected. If `xcode` is not connected, skip stage 6
and say so. If XcodeBuildMCP is not connected, skip stage 5 and say so. Everything else still runs.

### Step B. Full pipeline (stage 1, background, 20–30 min the first time)

Run `bash .claude/skills/mac-build/scripts/build-all.sh`. Read `build/mac/<timestamp>/summary.md` when it finishes.
Do not poll.

- Everything passed: go to Step E.
- Compile errors: stage 2. One `swift-builder` agent per package, in dependency order (TrapCore, then TrapDesign,
  then TrapData, TrapWeather and TrapPlatform in parallel, then ShotTimer, TrapReports, TrapApp, and the app).
- Test failures: stage 3. One `sim-tester` agent per package.
- `fixtures-current` failed: stop and ask me. Never regenerate fixtures.

Rerun only what failed (`build-all.sh --only <step>`), at most three rounds per failure. Anything still failing after
three rounds goes under **Open** in the record.

### Step C. The app runs (stage 4)

Run `bash .claude/skills/mac-build/scripts/run-demo.sh --section record`. Read the screenshot. It must show the Record
screen with the sample round. Then dispatch `app-verifier` with the `.app` path and the full set of sections, light and
dark, iPhone and iPad. Fix only the visual defects that are plainly wrong and say which ones you fixed.

### Step D. Smoke and design (stages 5 and 6, if connected)

- **Stage 5:** `build_run_sim`, `snapshot_ui`, check the accessibility identifiers in the skill, `stop_app_sim`.
- **Stage 6:** dispatch `design-reviewer` for `RenderPreview` in light and dark. This closes the row
  "Design preview rendered light and dark ⏳ Mac".

### Step E. Record and commit (stage 7)

Dispatch `progress-scribe` with the run folder, what passed, what was fixed (files), what is open, and which `⏳ Mac`
rows are now verified. It writes `docs/mac-sessions/<date>.md` and updates `docs/progress.md`.

Then commit locally: code fixes per package first, then the docs. Do not push.

### Step F. Phase check (use the phase map, then stop at the gates)

Work through the phases in `docs/phases/README.md`. For each phase, do what the Mac can do, and stop at what it
cannot.

| Phase | Name | What the Mac can do autonomously | Stop and ask me for |
|:-:|---|---|---|
| 0 | Discovery, architecture, decisions | nothing new (done) | nothing |
| 1 | Foundation, tooling, tokens | stages 0–2 and 6: CI green locally, design preview rendered light and dark | nothing |
| 2 | Pure domain core | `swift test` for TrapCore and the golden tests (stages 1–3) | any fixture regeneration |
| 3 | Local store and repositories | `TrapData` tests, `saveMany` rollback, import of 7.x shapes (stages 1–3) | the 2,000-round list timing on the phone |
| 4 | Shot timer engine | `ShotTimer` package tests; the detector regression set if `Tools/detector-fixtures/` has recordings (stage 1) | the DJI receiver checks, plug and unplug, the one-hour battery row, any detector change |
| 5 | Record and Timer screens | UI test (`ui-test` step), demo-mode screenshots, iPad layout in the simulator | a full round on a real range, kill-and-resume on the phone, iPad Split View on the device |
| 6 | Rounds, Analysis, Schemes, exporters | exporter and analysis tests, CSV byte-identical check on golden fixtures | the 2,000-round first-screen timing, selectable scorecard PDF text on the device |
| 7 | Settings, data, platform behaviour | backup and restore round-trip tests, notification and network policy tests | every lifecycle, power and network check on the device; deleting the Web folder (ask first) |
| 8 | Release and App Store | `build-all.sh` clean on the current commit (a precondition only) | every archive, upload, TestFlight step, and the App Store submission |
| 9 | Operate and iterate | `operate` skill's per-iOS-beta run: detector regression set and UI test on the new iOS | App Store Connect and support-bundle triage (needs files from me) |

For each phase, write one line in the session record: **verified on Mac**, **needs device**, or **needs you**. Do not
mark an exit gate as passed unless its evidence is in the record.

---

## 3. When you stop

End the run with one message:

1. **Passed on Mac:** the stage table from `summary.md`, with the paths of the run folder and the session record.
2. **Fixed:** files changed, by commit.
3. **Open:** what failed, with the compiler or assertion line.
4. **Needs you:** the device checks, the upload decision, and any approval you have to give. Use the phase table above.
5. **Next:** the one command you run next (for device work, `/mac-device`; for release, `/mac-release`).

Do not push. Do not upload. Wait for me.
