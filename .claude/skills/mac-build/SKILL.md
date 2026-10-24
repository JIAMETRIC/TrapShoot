---
name: mac-build
description: Build, test and run TrapShooterPro on a Mac with Xcode, end to end, through a fixed sequence of stages (preflight, golden fixtures, swift test, app build, simulator package tests, demo run with screenshots, design preview, progress report) with specialised agents for each stage. Use on the MacBook when asked to "build the app", "run the Mac build", "compile everything", "get the app running in the simulator", "verify on the Mac", or at the start of any Mac session. Not for a Windows or Linux session (there it stops at preflight).
---

# Mac build: the orchestration

You are the conductor. The stages run in order; each has a script that does the mechanical part and an agent that
does the judgement part. You run the scripts yourself, read their summaries, and dispatch agents only where a stage
fails or needs eyes. Nothing in this skill changes what the app does; it finds out whether what we wrote compiles,
passes and looks right on a Mac, and fixes what the Mac finds.

**Read first, every time:** `CLAUDE.md` (rules 1, 2, 4, 6, 9, 11), `docs/progress.md` (what is still marked ⏳ Mac),
and `.claude/skills/mac-build/reference/stages.md` (what each stage proves and how long it takes).

## Fixed conventions

- All scripts live in `.claude/skills/mac-build/scripts/` and are run from the repository root with `bash`.
- Every run writes to `build/mac/<timestamp>/` (git-ignored): one log per step, `.xcresult` bundles, `summary.md`.
  Hand the folder path, never log excerpts, to agents; they read with `summarize-log.sh`.
- The simulator is chosen by `lib.sh` (newest iPhone Pro). Override with `SIM="iPhone 17 Pro"` only if the default is wrong.
- Anything that can take more than two minutes (`build-all.sh`, simulator tests, the first `xcodebuild` after a clean)
  runs with `run_in_background: true`; read the summary when it finishes. Do not poll.
- XcodeBuildMCP: before its first build/run/test call in the session, call `session_show_defaults`; if the project,
  scheme or simulator is missing, `session_set_defaults` with project `TrapShooterPro.xcodeproj`, scheme
  `TrapShooterPro`, and the simulator name `lib.sh` picked. Then `build_run_sim`, `screenshot`, `snapshot_ui` work
  with empty arguments.
- Xcode's own bridge (`xcode` MCP server) is optional; it needs Xcode open with the project. Use it for
  `RenderPreview` in stage 6 and for live diagnostics; skip stage 6 with a note if it is not connected.

## Stages

Keep a task list with one step per stage. Advance only when a stage's exit criterion is met or explicitly skipped.

### 0. Preflight (2 min)

```bash
bash .claude/skills/mac-build/scripts/preflight.sh
```

- Any `FAIL` line: stop, show the lines, tell the user the exact command from the line. Do not continue.
- `WARN` lines limit later stages (no iPad → no iPad screenshots; no mcpbridge → no stage 6; dirty tree → say so in
  the report). Note them; continue.
- Not macOS: this skill does nothing else. Say so in one line and stop.

### 1. Full pipeline, one pass (15–30 min, background)

```bash
bash .claude/skills/mac-build/scripts/build-all.sh
```

Runs every CI step locally and keeps going past failures. When it finishes, read `build/mac/<ts>/summary.md`.

- Everything passed: skip to stage 4.
- `fixtures-current` failed: the fixtures differ from the JavaScript. Never regenerate them to make the step pass.
  Check `git status`; if a fixture was edited by hand, restore it. If `generate.js` or the reference page changed,
  stop and ask. (This is rule 2.)
- Other failures: stage 2 or 3, by kind.

### 2. Compile errors (fix loop)

For each failed step whose log has `error:` lines that are compiler errors (not test failures), dispatch one
**swift-builder** agent per package, in dependency order: TrapCore → TrapDesign → TrapData, TrapWeather, TrapPlatform
(these three in parallel) → ShotTimer → TrapReports → TrapApp → app. A package that depends on a broken one waits.

Brief for each: the package name, the run folder, the constraint list from CLAUDE.md rules 1, 2, 9 and 11, and
"rerun `test-package.sh <pkg> --build-only` until it compiles, then `test-package.sh <pkg>` once; report the diff
stat and anything you did not fix." The agent must not touch `AudioDetector.swift` detection logic, fixtures,
`Tools/golden/`, or the document v2 / CSV formats. If it says a fix needs one of those, stop and tell the user.

After the agents return, rerun only what failed: `build-all.sh --only sim` or `--only pure` etc. Then stage 3.

### 3. Test failures (triage loop)

For each step with failing tests (and no compile errors left), dispatch one **sim-tester** agent per package with the
run folder. Its job is to decide, test by test, whether the Swift or the test is wrong:

- Golden tests (`TrapCoreTests` against `Fixtures/`): the Swift is wrong. Always. The agent fixes the Swift.
- Other tests: fix the code when the test states the intended behaviour; fix the test only when it tests an
  implementation detail that legitimately changed, and say so in the report.
- A test that needs the microphone, the network or a device cannot pass in the simulator and must be marked or
  skipped with `XCTSkip` and a reason, never deleted.

Rerun the failed step; repeat at most three rounds. A failure that survives three rounds goes to the report as open.

### 4. The app runs (10 min)

```bash
bash .claude/skills/mac-build/scripts/run-demo.sh --section record
```

Builds, installs and launches in demo mode on the iPhone simulator and prints 20 s of log plus a screenshot path.
Look at the screenshot (Read the PNG). It must show the Record screen with the sample round, not a blank view or a
crash. Then dispatch **app-verifier** with the `.app` path from the output: it takes the full set (six sections,
light and dark, iPhone and iPad) with `run-demo.sh --no-build --screenshots build/mac/<ts>/shots`, checks each
picture against `docs/design-system.md`, scans the launch logs for crashes and `TrapLog` errors, and returns a table.
A crash is a stage-2/3 problem again (fix, rerun). Visual defects go to the report with the screenshot path; fix
only the ones that are plainly wrong (clipped text, hard-coded colour visible in dark mode, missing tab).

### 5. XcodeBuildMCP smoke (5 min, optional when stage 4 passed)

Through the MCP server: `build_run_sim` with defaults, then `snapshot_ui` and look for the accessibility identifiers
`docs/testing.md` plans for the UI tests (`record.result.hitFirst`, `timer.start`, `record.target.11`). They are not
in the sources yet, so their absence is a known gap to list in the report, not a failure. `stop_app_sim`. Skipped
when the server is not connected; say so in the report.

### 6. Design preview, light and dark (10 min, needs the Xcode bridge)

Dispatch **design-reviewer**. It renders `#Preview("TrapDesign")` in
`Packages/TrapDesign/Sources/TrapDesign/BWComponents.swift` through the bridge's `RenderPreview` in light and dark,
compares against `docs/design-system.md` (tokens, contrast, 44 pt targets, Dynamic Type at accessibility sizes), and
returns findings with image paths. This is the "Design preview rendered light and dark ⏳ Mac" item in progress.md.

### 7. Report and record (5 min)

Dispatch **progress-scribe** with: the run folder(s), the list of what passed, what was fixed (files), what stays
open, and which `⏳ Mac` items in `docs/progress.md` are now verified. It writes `docs/mac-sessions/<date>.md` (the
session record, modelled on `docs/phases/gates/PHASE_GATE_TEMPLATE.md`) and updates `docs/progress.md` lines and its
"Last updated" date. It does not commit.

Then you commit, in small commits with one topic each (CLAUDE.md rule 10): code fixes per package first, then the
docs. Push only if the user says so; CI on `main` is the second opinion. Show the final table to the user.

## What you never do here

- Edit `AudioDetector.swift` detection logic, regenerate fixtures, or change document v2 / CSV layouts to get green.
- Delete a failing test. Skip with `XCTSkip` and a reason, or fix.
- Report "passes" from a log you did not read. The summary table comes from `summary.md`, not from memory.
- Claim device behaviour (microphone, DJI receiver, timing) from the simulator. Those are `/mac-device`.
- Run `Scripts/archive.sh` or anything that signs or uploads. That is `/mac-release`, with the user's say-so.

## Agents

| Agent | Stage | Does |
|---|---|---|
| `mac-preflight` | 0 | runs preflight, explains every WARN/FAIL with the exact fix command |
| `swift-builder` | 2 | compile-fix loop for one package or the app, within the rules |
| `sim-tester` | 3 | runs and triages one package's tests; Swift vs test decision |
| `app-verifier` | 4 | demo run, full screenshot set, crash and log scan, visual table |
| `design-reviewer` | 6 | RenderPreview light/dark, design-system audit |
| `progress-scribe` | 7 | session record under `docs/mac-sessions/`, progress.md update |

Definitions: `.claude/agents/*.md`. Give every agent the run folder path and the package name; nothing else needs
restating, the agent definition carries the rules.
