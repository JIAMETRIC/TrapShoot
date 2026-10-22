# TrapShooterPro — the four parts, in native iOS terms

One page. Every row points at code or a document in this repository.

## Part 1 — Computer Science Fundamentals

| Topic | Native iOS term here | Where |
|---|---|---|
| OOP: encapsulation | the detector and recorder are internal to `ShotTimer`; the app sees `TimerSession` and typed `TimerEvent`s; SwiftData's `RoundRecord` is internal to `TrapData`, the app sees `Round` | `Packages/ShotTimer`, `Packages/TrapData` |
| OOP: value vs reference | `struct Round` and all domain data are values (structural equality, cheap copies, undo = keep the old value); `@Observable @MainActor` classes only for things with a lifetime (`TimerSession`, repositories, monitors) | `TrapCore/Round.swift`, `ShotTimer/TimerSession.swift` |
| OOP: abstraction at real seams | protocols only where a second implementation exists: `RoundRepository`, `ShotTimerControlling`, `DocumentExporter`, `WeatherService`, `HTTPClient`, `LocalNotifying`, `LifecycleParticipant` | ADR‑005 |
| OOP: aggregate and state machine | `RoundSession`: setup → recording → complete; start guard, station‑quota guard, NO TARGET, skip/re‑time, bounded undo, typed errors | `TrapCore/RoundSession.swift` |
| OOP: polymorphism and factory | `DocumentExporter<Input>` with a template‑method `export`; CSV, backup, PNG, PDF exporters; `ExporterFactory` per screen | `Packages/TrapReports` |
| DSA: real‑time audio | ring buffers, running sums, biquad filters, lock‑protected state, zero allocation per buffer, timing in samples | `AudioDetector.swift` (unchanged) |
| DSA: domain | fixed 25‑slot arrays; station rule arithmetic; median outlier filter; 3×3 least squares with partial pivoting; fixed‑point iteration for break distance; one‑pass dictionary aggregation | `RoundRules`, `TrapAnalysis`, `BreakDistance`, `Analysis` |
| DSA: storage | indexed columns + document payload; column fetches with filter, paging and count; denormalised `score`, `recorded`, `place` as the pre‑aggregated summary | `TrapData/Queries.swift`, `Schema.swift` |
| System design | local‑first, device is the only source of truth; three concurrency domains (audio thread, main actor, recorder queue) with fixed hand‑offs; failure handling table; ADR‑001…016 | `docs/architecture.md` |

## Part 2 — Mobile Platform Concepts

| Topic | Native iOS term here | Where |
|---|---|---|
| App lifecycle | `ScenePhase` → `LifecycleCoordinator` → four ordered participant calls; save on resign‑active, stop timer and close recording on background inside a `UIBackgroundTask`, refresh inputs on foreground; no background audio mode (ADR‑010); `ScreenAwake` ref‑counts the idle timer | `TrapPlatform/AppLifecycle.swift` |
| Offline storage | SwiftData with a versioned schema and migration plan, `completeUntilFirstUserAuthentication` file protection, recordings in Documents for the Files app, `RecordingsStore`, `StorageReport`, typed `CodableDefaults`, `BackupFile` (Transferable) | `TrapData`, `TrapPlatform/Storage.swift` |
| Push notifications | none remote (no server, no APNs); `LocalNotifier` schedules one passive unfinished‑round reminder, permission asked at that moment, never at launch; `SilentNotifier` for previews (ADR‑011) | `TrapPlatform/LocalNotifications.swift` |
| Battery and network constraints | `PowerMonitor` (battery, Low Power Mode, thermal) → one advice value: slower level meter, round audio off by default, critical warnings; `NetworkMonitor` (`NWPathMonitor`) gates the only network call; `URLSession` with 15 s timeout, no cache, no waiting, no constrained access (ADR‑012) | `TrapPlatform/PowerMonitor.swift`, `NetworkMonitor.swift`, `TrapWeather` |
| App Store publishing | `PrivacyInfo.xcprivacy` (no tracking, no collected data, required‑reason APIs) in the project; `ExportOptions.plist` + `Scripts/archive.sh`; privacy answers, review notes, listing text, quality gates; icon label TrapShoot; iOS 17, iPhone + iPad (ADR‑013) | `docs/app-store.md` |

## Part 3 — Software Engineering Foundations

| Topic | Native iOS term here | Where |
|---|---|---|
| Databases | SwiftData: one table, primary key on the web app's ids, ISO strings that sort, `FetchDescriptor` with `#Predicate`, `propertiesToFetch`, `fetchLimit/Offset`, `fetchCount`; `saveMany` = autosave off, one save, rollback; `VersionedSchema` + `SchemaMigrationPlan`; UserDefaults as key‑value; no NoSQL server | `TrapData/Schema.swift`, `Queries.swift` |
| APIs and networking | one unauthenticated REST GET over HTTPS (Open‑Meteo); `Endpoint`, `HTTPClient`, transient‑only retry with backoff, user‑facing `HTTPError`; `StubURLProtocol` integration tests; no GraphQL, WebSockets, JWT or OAuth (ADR‑014) | `TrapWeather/HTTPClient.swift` |
| Version control | trunk‑based, short `feat/ fix/ chore/` branches, PR template, CI required, tags `v8.0.0-b1`, `pbxproj merge=union` | `docs/git-workflow.md`, `.github/`, `.gitattributes` |
| Testing | golden tests generated from the JavaScript; unit tests per package; SwiftData in memory; HTTP through a stub; performance `measure` budgets; detector regression on range recordings; UI tests via a scripted timer | `docs/testing.md`, every `Tests/` |
| Security | OWASP Mobile Top 10 mapping; `Validation.sanitized` + `Validation.issues` at every boundary; CSV formula‑injection guard; no credentials to hash or keep; ATS‑default HTTPS; privacy by construction | `docs/security.md`, `TrapCore/Validation.swift` |
| DevOps | GitHub Actions: fixtures current, `swift test` on macOS, simulator build and tests; manual TestFlight workflow with an App Store Connect API key; no Docker (iOS builds need macOS); `os.Logger` categories with privacy, signposts, MetricKit, support bundle (ADR‑015, 016) | `.github/workflows/`, `TrapPlatform/Diagnostics.swift` |
| Performance | budgets (launch < 400 ms, timer start < 300 ms, save < 10 ms, list < 50 ms, analysis of 1,000 rounds < 500 ms, < 10 % battery per hour) and how each is measured; caching of the shot table; lazy rendering of reports | `docs/performance.md` |
| Error handling and debugging | `UserFacingError` + `DisplayError` for anything on screen; states not alerts for expected conditions; sanitise‑then‑report imports; log categories; hidden debug screen; symptom checklist | `docs/debugging.md`, `TrapCore/Errors.swift` |

## Part 4 — Build: Phase‑Level Implementation

| Phase | Name | Status | Exit gate |
|:-:|---|---|---|
| 0 | Discovery, architecture, decisions | done | ADR‑001…016, plans and rules in the repo |
| 1 | Foundation, tooling, design tokens | done; CI green, design preview not yet rendered | baseline builds; CI green; design preview light and dark; breakpoints |
| 2 | Pure domain core (`TrapCore`) | done; `swift test` green in CI | all golden fixtures pass; `RoundSession` tests; no UI/storage imports |
| 3 | Local store (`TrapData`) | done; `swift test` green in CI, 2,000‑round timing on device pending | summaries, search, paging and rollback tests; 7.x import |
| 4 | Shot timer engine (`ShotTimer`) | package tests green in CI; DJI Mic Mini 2 is the reference receiver; device verification pending | regression set within 7 ms; receiver scenarios recover; < 10 % battery per hour |
| 5 | Record and Timer screens | next | full round on a real range; kill‑and‑resume; iPad split verified; UI test |
| 6 | Rounds, Analysis, Schemes, exporters | after 5 | 2,000‑round list < 50 ms; selectable PDF text; CSV identical |
| 7 | Settings, data, platform behaviours, Web folder deleted | after 6 | backup/restore round trip; lifecycle and notification policies on device; no JavaScript left |
| 8 | Release engineering and App Store | after 7 | external TestFlight with three shooters; submission accepted; `v8.0.0` tagged |
| 9 | Operate and iterate | ongoing | crash‑free > 99.5 % over 3 months; support bundles answered; iCloud evaluated |

Cross‑cutting matrix, risk register and per‑phase files: `docs/phases/`.

## What is true today

- 7 Swift packages (`TrapCore`, `ShotTimer`, `TrapData`, `TrapDesign`, `TrapWeather`, `TrapPlatform`, `TrapReports`), 6 golden fixture files, 10 phase files, 15 documents, CI and release workflows.
- On GitHub at `JIAMETRIC/TrapShooterPro`. CI is green on `main` (22 October 2026): golden fixtures current; `swift test` for TrapCore, TrapData and TrapWeather on macOS; the hybrid app builds; TrapPlatform tests pass in the simulator; ShotTimer and TrapDesign build.
- The first CI runs found three defects, all fixed: percentages rounded ties to even where the web app's `toFixed` rounds them away from zero (now `JSText.fixed`); encoding a round with NaN raised an Objective‑C exception that skipped the `saveMany` rollback and would have crashed the app (now `RoundDocumentError.notEncodable`); and one TrapData test compared two repositories holding different rounds.
- Not yet covered by CI: `TrapReports` (neither built nor tested), the scorecard and design previews, anything on a real device. The app target still runs the hybrid web page; no package is linked to it yet.
- Job logs need a signed‑in GitHub account; CI repeats `swift test` failure lines as an annotation, readable through the public API.
