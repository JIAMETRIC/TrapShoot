# Code review, 22 October 2026 — findings and what was done

Source: independent read-only review of `Packages/` (second reviewer, not anchored on the author). Full architecture evaluation: `docs/architecture-review.md`.

*Read-only review by a second reviewer, not anchored on the author's reading. Scope: every source and test under `Packages/`; the detector and recorder only inspected for the API `TimerSession` uses. Target iOS 17, Swift 5 language mode.*

## Compile blockers (two)

| # | Where | Problem | Fix |
|---|---|---|---|
| 1 | `TrapPlatform/AppLifecycle.swift:77-81` | `var id` is captured and mutated inside the `beginBackgroundTask` expiration handler, which the iOS 17/18 SDK imports as `@MainActor @Sendable`; mutating a captured `var` in concurrently executing code is a hard error even in Swift 5 mode | keep the identifier in a stored property or a small `final class Box` and end the task from there |
| 2 | `TrapData/Queries.swift:80-85` | one `#Predicate` with 11 comparisons, 6 captured flags and three `\|\|` groups is the shape that hits "unable to type‑check this expression in reasonable time" | replace flags with sentinel bounds (`dateFrom ?? ""`, `dateTo ?? "9999-99-99"`, ranges for scheme and recorded) and build the text clause as a separate predicate used only when a search term exists |

## Certain test failure (one)

| # | Where | Problem | Fix |
|---|---|---|---|
| 3 | `TrapCore/Tests/ValidationAndPerformanceTests.swift:32` | the test sets `startStation = 7`, so targets 0/5/10 fall on station 2, and the expected issue is `stationOverQuota(station: 2)`, not 1 | assert station 2, or put the three rights on targets 4/9/14 |

## Probable runtime defects

| # | Where | Problem | Fix |
|---|---|---|---|
| 4 | `TrapData/SwiftDataRepository.swift:17`, `Schema.swift:12-28` | the container is named `TrapShooterPro` and V1 is a hand‑written reconstruction; if build 8 used the default store name or a slightly different model, the old store is orphaned or the migration fails at launch | pin the configuration name and V1 model to exactly what build 8 shipped; add a migration test that opens a copied build‑8 store |
| 5 | `TrapCore/RoundDocument.swift:33,35,61` | `Int(v)` on a JSON Double traps for values outside Int range or non‑finite (a backup with `"session": 1e300` crashes the import) | `Int(exactly:)` or clamp before converting |
| 6 | `TrapCore/CSVExport.swift:52` | `String(Int64(v))` is guarded by `abs(v) < 1e21` but `Int64` overflows at 9.22e18 | guard with `abs(v) < 9_007_199_254_740_992` as `RoundDocument.jsNumber` already does |
| 7 | `TrapPlatform/AppLifecycle.swift:76-84` | `finishInBackground` runs `work()` synchronously and ends the background task at once, so asynchronous file finalisation gets no background time | take a completion or `async` work closure and end the task from its completion |
| 8 | `ShotTimer/TimerSession.swift:97` | starting an already running session stops the detector but does not end the open recording or cancel a pending restart | call `stop()` before restarting |

## Design findings

| # | Where | Finding | Fix |
|---|---|---|---|
| 9 | `TimerSession.swift:101,123` vs `AppLifecycle.swift:102-110` | `TimerSession` writes `isIdleTimerDisabled` directly while `ScreenAwake` exists to ref‑count it; `stop()` can clear another owner's hold | let the app layer hold and release `ScreenAwake`; the timer only exposes running state |
| 10 | `TimerTypes.swift:102-117`, `TimerSession.swift:26` | `ShotTimerControlling` omits `onEvent`, `sampleRate`, `isRecording`, `lastRecordingURL`, `settings`, `recordingToShare()`, so screens must downcast; `AudioRoute` and `TimedTarget` have no public init, so a fake timer cannot construct events | add the members to the protocol and public memberwise inits to the structs |
| 11 | `TimerSession.swift:136,233` | the `detector.tap` closures are inferred MainActor‑isolated though they run on the audio thread; harmless in Swift 5, a crash under Swift 6 runtime checks | write them `{ @Sendable buffer, ch in … }` |
| 12 | `TrapReports/Exporter.swift:35-50` | the whole `DocumentExporter` protocol is `@MainActor`, so CSV and backup generation and the file write run on the main thread | keep the protocol nonisolated, mark only the two scorecard renderers `@MainActor`, make `export` async |
| 13 | `SwiftDataRepository.swift:63-65`, `Backup.swift:70`, `SwiftDataRepository.swift:23-32` | `sessionIdentifiers()` loads every document blob; `Importer.merge` decodes a full document per row to test existence; `backfill` decodes every empty‑place round on every launch | `propertiesToFetch = [\.id, \.sessionId]`; existence by id; backfill once behind a stored flag |
| 14 | several | JS `Math.round` ported twice, sky and wind names three times, the Recordings folder and the store path twice | expose `Sky`/`Wind` and `jsRound` from TrapCore; derive paths from one constant |
| 15 | ShotTimer, TrapReports, `TrapDataTests.swift:110` | no test targets for ShotTimer and TrapReports though several parts are pure; `TimerSession` hard‑codes its collaborators; the "all or nothing" test asserts a tautology and never exercises a failing batch | add the two test targets; inject detector and recorder behind small protocols; make `saveMany` fail mid‑batch to prove the rollback |
| 16 | `TimerSession.swift:178-209` | the three NotificationCenter observers are never removed; no `deinit` | remove them in `stop()` or `deinit` |

Minor: `nonisolated(unsafe)` in the HTTP tests needs Swift 5.10+ (Xcode 16 is fine); two test targets import TrapCore without declaring it as a dependency (works via transitive search paths).

Everything specifically checked and found correct: nested `@Model` classes inside `VersionedSchema` enums, `localizedStandardContains` in `#Predicate`, every `MainActor.assumeIsolated` call site, `@Observable` and `@ObservationIgnored` usage, `Font.width(.condensed)` and the other iOS 16/17 SwiftUI APIs, the optional‑vs‑non‑optional `XCTAssertEqual` calls, the fixture decoding helpers, and all `Package.swift` manifests.

## Reviewer's verdict

Unusually clean code for an uncompiled port. The domain layer and its golden‑fixture tests are tight, the type and access‑control design is coherent, and the SDK usage is accurate for iOS 17. Two plausible compile blockers, both one‑line fixes; one test assertion will fail. The remaining risks are a handful of numeric‑conversion traps on untrusted input, the store‑name and V1‑fidelity assumption that cannot be verified from source, and architectural seams (timer protocol, exporter isolation, duplicated constants) that should be settled before the app target grows on top of them. Expect it to compile after the two fixes, with warnings but no further errors.


## Status after the fix commit

| # | Status |
|---|---|
| 1 | fixed: `BackgroundTaskHandle` owns the identifier; `finishInBackground` takes async work and ends the task after it |
| 2 | fixed: sentinel bounds, one captured Bool, text clause in a separate predicate |
| 3 | fixed: asserts station 2 |
| 4 | removed: single schema V1 (the hybrid app never had a SwiftData store); store name from `AppConstants` |
| 5 | fixed: `JSMath.safeInt` for session, field and NO TARGET counts |
| 6 | fixed: 2^53 guard in `JSText.number` |
| 7 | fixed: see 1; README adapter waits for the recorder before ending the task |
| 8 | fixed: `begin` calls `stop()` first |
| 9 | fixed: `TimerSession` no longer touches the idle timer; the app holds `ScreenAwake` |
| 10 | fixed: protocol carries every member a screen needs; `AudioRoute`, `TimedTarget` have public inits |
| 11 | fixed: taps are `@Sendable` |
| 12 | fixed: protocol nonisolated; renderers `MainActor.assumeIsolated` inside `data(for:)` |
| 13 | fixed: `sessionIdentifiers` fetches two columns; import checks an id set; backfill removed with V2 |
| 14 | fixed: `Sky`, `Wind`, `JSMath`, `AppConstants` in TrapCore, used by Analysis, Weather, Reports, Platform, Data |
| 15 | fixed: `ShotTimerTests` and `TrapReportsTests` added; detector and recorder injected behind `ShotDetecting` / `RoundRecording`; `saveMany` rollback proven with a NaN round |
| 16 | fixed: observers removed in `stop()` and `deinit` |

Also: test targets of TrapData, TrapWeather and TrapReports now declare TrapCore explicitly; `nonisolated(unsafe)` in the HTTP tests needs Xcode 16 or newer, which the project requires anyway.
