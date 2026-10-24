# Phase map: which skill, stage and agent finishes each open item

`docs/progress.md` rows that are not ✅ as of 24 October 2026, and what closes them. Everything that can be written
without a Mac is already in the repository; the Mac session runs the stages, the owner provides recordings and range
time.

| Phase | Open row | Closed by | Who / where |
|---|---|---|---|
| 1 | Design preview rendered light and dark | `/mac-build` stage 6 (`design-reviewer`) | Mac |
| 3 | 2,000 rounds first list screen < 50 ms | `/mac-device` row 11 | Mac + iPhone |
| 4 | Port name of the DJI receiver confirmed | `/mac-device` row 2 | Mac + iPhone + DJI |
| 4 | Detector regression recordings with expected times | `/detector-fixtures` (ffmpeg on any machine; the owner's nine videos and the 18 Oct test) | owner + any machine |
| 4 | `FileAnalyzer` and regression test target | written: `FileAnalyzer.swift`, `DetectorFixture.swift`, `DetectorRegressionTests`; runs in CI and `/mac-build` stage 1; passes for real once fixtures exist | done, awaits fixtures |
| 4 | Device checks: plug/unplug, call, Low Power Mode, 1 h battery | `/mac-device` rows 1, 5, 6, 8, 10 | Mac + iPhone + DJI |
| 5 | Record and Timer screens, tabs, split, Dynamic Type, VoiceOver (🟡) | `/mac-build` stage 4 (`app-verifier`), `/mac-device` row 17 | Mac, then iPhone |
| 5 | Range flow through a scripted timer | written: `TrapShooterProUITests` through `DemoTimer -uitest`; CI step "UI test"; `/mac-build` stage 1 `ui-test` | done, verified by CI |
| 5 | Full round on a real range; kill-and-resume on device | range session (owner); `/mac-device` row 13 | owner; Mac + iPhone |
| 6 | Rounds, Analysis, Schemes, exporters (🟡) | `/mac-build` stage 4 screenshots; `/mac-device` rows 11, 18 | Mac, then iPhone |
| 6 | Performance gates on device | `/mac-device` rows 11, 14 | Mac + iPhone |
| 7 | Settings, Data, About; lifecycle, power, network, reminder, MetricKit (🟡) | `/mac-device` rows 7, 8, 12, 15, 16 | Mac + iPhone |
| 7 | Backup → reinstall → restore on device | `/mac-device` row 12 | Mac + iPhone |
| 8 | Tag `v8.0.0-b1`, API key, TestFlight internal/external, screenshots, submission | `/mac-release` | Mac + Apple Developer account + testers |
| 9 | Crash-free, hangs, launch, support bundles, cadence, options | `/operate` with `support-triage` | any machine, after release |

## What stays with the owner, by design

- Recording the regression set at the range (the skill converts and checks; a person reads the waveform).
- Shooting a full round with the native app, and the three external testers' range sessions.
- Apple Developer Program membership, App Store Connect records, the API key for `release.yml`.
- Reading App Store Connect pages (no API access from the repository, on purpose: no secrets in it).

## Order on the first Mac day

`/mac-build` → `/mac-device` (with the DJI receiver) → `/detector-fixtures` for any recordings already on hand →
`/mac-release` when the account is active. `/operate` begins after the first TestFlight build is in testers' hands.
