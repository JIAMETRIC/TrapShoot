# TrapShooterPro — progress tracker

One line per deliverable, updated with every commit that changes one. Plan and exit gates: `docs/phases/`.
Legend: ✅ done and verified in CI · 🟡 built and unit‑tested in CI; the gate's device, range or Mac check still to do ·
🔨 in progress · ⏳ waiting on the owner (recordings, iPhone, range, Mac, Apple account) · ⬜ not started.

*Last updated: 22 October 2026*

## Verification available

| Where | What it can prove |
|---|---|
| GitHub Actions (macOS runners) | compiles every package and the app; unit and simulator tests; golden fixtures |
| Owner's iPhone + DJI Mic Mini 2 | timing, receiver behaviour, battery, kill‑and‑resume, real‑range round |
| A Mac with Xcode | SwiftUI previews, Instruments, archive and App Store submission |

## Phase 0 — Discovery and decisions ✅

| Deliverable | State |
|---|---|
| Plan, decisions, ADR‑001…016, design system, engineering docs, App Store checklist | ✅ |

## Phase 1 — Foundation

| Deliverable | State |
|---|---|
| Repository on GitHub (`JIAMETRIC/TrapShooterPro`), CI and release workflows | ✅ |
| CI green on `main` (fixtures, `swift test`, simulator build and tests) | ✅ |
| CI failure lines published as annotations (logs need sign‑in) | ✅ |
| `TrapDesign` tokens, components, breakpoints | ✅ builds in CI |
| Design preview rendered light and dark | ⏳ Mac |

## Phase 2 — Domain core (`TrapCore`) ✅

| Deliverable | State |
|---|---|
| All golden fixtures pass; `RoundSession` tests; no UI or storage imports | ✅ |
| `JSText.fixed` (JavaScript `toFixed` rounding) | ✅ |

## Phase 3 — Local store (`TrapData`)

| Deliverable | State |
|---|---|
| Repositories, summaries, filters, paging, `saveMany` rollback, backup, importer | ✅ |
| Unencodable rounds throw `RoundDocumentError` instead of crashing | ✅ |
| 2,000 rounds: first list screen < 50 ms on an iPhone 12 | ⏳ iPhone |

## Phase 4 — Shot timer (`ShotTimer`)

| Deliverable | State |
|---|---|
| Detector and recorder byte‑identical to the app; `TimerSession` replaces `MicBridge` | ✅ |
| `ShotTimerTests` run in CI | ✅ |
| DJI Mic Mini 2 as reference receiver: recognised, preferred under System default, named on the check line | ✅ |
| Port name of the DJI receiver confirmed on a device | ⏳ iPhone + DJI |
| Detector regression recordings (9 range videos, 18 Oct mic test) with expected times | ⏳ owner |
| `FileAnalyzer` ("Time a recording") and regression test target | ⬜ after the recordings |
| Device checks: plug/unplug, call, Low Power Mode, 1 h < 10 % battery | ⏳ iPhone + DJI |

## Phase 5 — Record and Timer screens

| Deliverable | State |
|---|---|
| `TrapReports` built and tested in CI | ✅ |
| Local packages linked into the Xcode project (`TrapApp`, ADR‑017) | ✅ |
| Native app root replaces the WebView | ✅ |
| `RecordModel`, `TimingFlow` (7.0.7 range flow), lifecycle, kill‑and‑resume | 🟡 |
| Record screen | 🟡 |
| Timer screen | 🟡 |
| iPhone tabs, iPad split, keyboard, VoiceOver, Dynamic Type | 🟡 |
| Range flow tested through a scripted timer (`RecordFlowTests`) | 🟡 |
| Full round on a real range; kill‑and‑resume on device | ⏳ range |

## Phase 6 — Rounds, Analysis, Schemes, exporters

| Deliverable | State |
|---|---|
| Rounds list (search, chips, paging, delete with undo, iPad master‑detail) | 🟡 |
| Analysis (tiles, trends, tables, trap analysis) | 🟡 |
| Schemes table | 🟡 |
| Exports through `ExporterFactory` and the share sheet, temp files removed | 🟡 |
| Performance gates on device | ⏳ iPhone |

## Phase 7 — Settings, data, platform

| Deliverable | State |
|---|---|
| Settings, Data, About screens | 🟡 |
| Lifecycle, power, network, reminder, MetricKit wired | 🟡 |
| `Web/`, Supabase and hybrid Swift files deleted; 7.0.7 page kept only as the golden reference in `Tools/golden/reference/` | ✅ |
| Backup → reinstall → restore on device | ⏳ iPhone |

## Phase 8 — Release

| Deliverable | State |
|---|---|
| Version 8.0.0 build 1 in the project | ✅ |
| Privacy manifest matches the APIs used (UserDefaults, file timestamps, disk space) | ✅ |
| Review notes match the native test path; NO TARGET bar 56 pt | ✅ |
| Privacy policy and support pages (`docs/privacy.md`, `docs/support.md`) | 🟡 contact email to fill in |
| Tag `v8.0.0-b1` on the commit that is uploaded to TestFlight | ⏳ first upload |
| App Store Connect API key and secrets for `release.yml` | ⏳ Apple Developer account |
| TestFlight internal, then external (three shooters, three range sessions) | ⏳ owner |
| Screenshots, privacy answers, review notes, submission | ⏳ owner + Mac |

## Phase 9 — Operate

| Deliverable | State |
|---|---|
| MetricKit service levels, support bundles, regression run per iOS beta | ⬜ after release |

## Log

| Date | Commit | Change |
|---|---|---|
| 2026‑10‑22 | `d231a62` | CI publishes failure lines as annotations |
| 2026‑10‑22 | `d3dd287` | TrapCore: `toFixed` rounding fixed, CI TrapCore green |
| 2026‑10‑22 | `a769e74` | TrapData: NaN crash and test fixed; whole CI green |
| 2026‑10‑22 | `e268864` | Docs record the green CI |
| 2026‑10‑22 | `2aa796f` | ShotTimer: DJI Mic Mini 2 preferred; ShotTimer tests in CI |
| 2026‑10‑22 | `3964ab8` | TrapReports tested in CI; this tracker |
| 2026‑10‑22 | `27f40f5` | `TrapApp` package linked into the Xcode project (ADR‑017); hybrid sources out of the target |
| 2026‑10‑22 | `31cd9c7` | Native Record, Timer, Rounds, Analysis, Schemes, Settings; `TimingFlow`; CI green |
| 2026‑10‑22 | `e4375cf` | Phase 7 clean break: web app and hybrid sources deleted; README for the native app |
