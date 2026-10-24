---
name: detector-fixtures
description: Turn the owner's range videos and microphone tests into detector regression fixtures (mono 48 kHz audio plus a JSON of expected call-to-shot times) in Tools/detector-fixtures/, and run the regression set. Works on Windows, Linux or a Mac with ffmpeg; only the run itself needs a Mac. Use when the owner shares recordings, when asked to "add a fixture", "make the regression set", "check the detector against the recordings", or before any change near AudioDetector.swift (CLAUDE.md rule 1).
---

# Detector fixtures: from a recording to a regression test

The detector (`Packages/ShotTimer/Sources/ShotTimer/AudioDetector.swift`) may only change with a fixture-based
regression run. This skill builds the fixtures. Format, rules and the manual steps: `Tools/detector-fixtures/README.md`.
Runner: `DetectorRegressionTests` in `Packages/ShotTimer`, through `FileAnalyzer`.

## Inputs from the owner

Nine range videos and the 18 October microphone test. Ask for them as files (AirDrop, Files, a shared folder), not
as messages; note for each which receiver was used (DJI Mic Mini 2 or the phone) and how many targets it holds.

## Steps per recording

1. Convert and scaffold (any machine with ffmpeg):
   ```bash
   bash Tools/detector-fixtures/make-fixture.sh <video or audio> <name> "<receiver>" [start] [duration]
   ```
   Names: `YYYY-MM-DD-<receiver>-<what>`, e.g. `2026-10-18-dji-mictest`. Trim to the targets with start and duration;
   keep each `.m4a` under 10 MB.
2. Expected times. Open the `.m4a` in an editor with a sample cursor (Audacity). For every target: call onset is where
   the voice first rises above the background; shots are the sharp broadband spikes. `firstMs = shot1 - call`,
   `secondMs = shot2 - call` or `null`. Fill `targets[]` in order; fill `notes` with what must be ignored (the next
   shooter, a dropped shell). Two independent readings within 3 ms, or the recording is not a fixture.
3. Settings: only what differed from the app's defaults on that day (`callDb`, `shotDb`, `gateDb`, `secondWinMs`,
   `offset`). Usually nothing.
4. Run it (Mac):
   ```bash
   bash .claude/skills/mac-build/scripts/test-package.sh ShotTimer --filter DetectorRegressionTests/testEveryFixtureMatchesWithinTolerance
   ```
   The test prints each fixture's detected first shots. A mismatch names the target and both numbers.

## Reading a mismatch

- **Detected but not expected / expected but not detected**: count the targets again; a neighbour's shot or a dry
  fire is usually the cause. Fix the JSON only if the listening confirms the JSON was wrong.
- **1st shot off by more than 7 ms, consistently across targets**: a call-onset reading problem, in the JSON or in
  the detector's back-tracking. Compare onsets by eye at sample zoom before concluding anything about the detector.
- **Off on one target only**: listen to that target; echo, double call, or a shell hitting the floor.
- A fixture that fails and is right is a detector finding. Record it in `docs/mac-sessions/`, do not change the
  detector in the same commit, and never edit the fixture's numbers to go green (README rules).

## When the set exists

- CI runs it in the ShotTimer step on every push; `/mac-build` stage 1 runs it locally; `/mac-release` runs it on the
  Release configuration (`test-package.sh ShotTimer --release`) before any upload.
- `docs/progress.md` Phase 4: "Detector regression recordings" → ✅ with the count, "`FileAnalyzer` and regression
  test target" → ✅. Dispatch **progress-scribe** with the fixture list and the run output.
