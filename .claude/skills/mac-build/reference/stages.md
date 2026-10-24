# mac-build stages: what each proves, how long, how it fails

| # | Stage | Script / tool | Proves | Typical time (M-series, warm) | First run (cold DerivedData) |
|---|---|---|---|---|---|
| 0 | Preflight | `preflight.sh` | Xcode, simulators, Node, MCP bridge, git state | 10 s | 10 s |
| 1 | Pipeline | `build-all.sh` | the same steps as `.github/workflows/ci.yml` | 6–10 min | 20–30 min |
| 2 | Compile fix | `test-package.sh <pkg> --build-only` | one package compiles | 30 s–2 min per round | up to 5 min |
| 3 | Test triage | `test-package.sh <pkg> [--filter X]` | one package's tests pass | 1–3 min | 5 min |
| 4 | Demo run | `run-demo.sh` | the app launches, draws, does not crash; screenshots | 3 min + 4 min screenshots | 8 min |
| 5 | MCP smoke | XcodeBuildMCP `build_run_sim`, `snapshot_ui` | MCP path works; accessibility ids present | 2 min | 5 min |
| 6 | Design preview | Xcode bridge `RenderPreview` | design system renders in light and dark | 3 min | 5 min |
| 7 | Report | `progress-scribe` | the session leaves a record and progress.md is honest | 3 min | 3 min |

## Step names in `summary.md`

`fixtures-current`, `swift-test-TrapCore`, `swift-test-TrapData`, `swift-test-TrapWeather`, `app-build`,
`sim-test-TrapPlatform`, `sim-test-ShotTimer`, `sim-test-TrapReports`, `sim-test-TrapApp`, `design-build`.
Each has `<name>.log` beside the summary; simulator tests also have `<Package>.xcresult`.

## Dependency order for fixes

```
TrapCore ─┬─ TrapDesign ─┐
          ├─ TrapData ───┼─ TrapReports ─┐
          ├─ TrapWeather ┤               ├─ TrapApp ─ app target
          ├─ TrapPlatform┘               │
          └─ ShotTimer ──────────────────┘
```

A compile error in TrapCore shows up again in every package above it; fix bottom-up and rerun top-down.

## Reading a failure quickly

```bash
bash .claude/skills/mac-build/scripts/summarize-log.sh build/mac/<ts>            # the whole run
bash .claude/skills/mac-build/scripts/summarize-log.sh build/mac/<ts>/sim-test-TrapApp.log
bash .claude/skills/mac-build/scripts/summarize-log.sh build/mac/<ts>/TrapApp.xcresult
```

## Known differences between CI and a local Mac

- CI pins Xcode 16.4 and `iPhone 16`; the Mac has whatever Xcode is installed and newer simulators. A warning that
  appears only locally is usually a newer SDK deprecation; fix it if cheap, otherwise note it.
- CI runs with a clean DerivedData every time. A local build that passes only after `rm -rf build/mac/DerivedData`
  points at a stale module cache, not at the code; note it and move on.
- CI has no Xcode GUI, so the Xcode bridge stages (6) exist only locally.
- `xcpretty` is on the CI runner; locally `lib.sh` uses `xcbeautify` when present, raw output otherwise. The logs
  are always the raw output.

## Simulator hygiene

- `xcrun simctl shutdown all` if the simulator misbehaves; `xcrun simctl erase <udid>` if demo data looks stale
  (demo mode wipes its own suite on launch, so this should not be needed).
- Two simulators at once (iPhone and iPad screenshots) are fine on 16 GB; more is not.

## What the simulator cannot tell you

Microphone input, the DJI Mic Mini 2 receiver, audio route changes, timing accuracy, battery, Low Power Mode,
background audio interruption, real launch time. All of that is `/mac-device` on the owner's iPhone.
