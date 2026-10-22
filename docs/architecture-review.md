# TrapShooterPro — Senior architect's evaluation

*22 October 2026 · repository state: 13 commits, 7 Swift packages, nothing compiled yet*

An honest evaluation needs a read that is not anchored on my own, so an independent reviewer is going through the Swift packages for compile and design defects while this assesses the architecture. The reviewer's file-level findings follow separately.

## Verdict

The architecture is sound and the decisions are the right ones for this product, but the project is at an unusual point: about 4,700 lines of Swift and 1,300 lines of documentation exist, and not one line has been compiled. The design risk is low. The execution risk is concentrated in a single fact, the absence of a compiler, and that risk grows with every commit until a Mac runs the tests. I would stop adding packages now and spend the next session entirely on making what exists build and pass.

## What is strong

- **The product decisions.** Local-first with no account, no WebView, iOS 17 universal, SF fonts, and the detector kept byte for byte. Each removes an App Review or range-reliability risk the 7.0.7 app carries. The decision records give reasons, which is rarer than it should be.
- **The dependency graph.** TrapCore imports nothing. Five packages depend on nothing or on TrapCore alone. Only TrapReports fans in, and it should. There is no cycle and no package reaches up into UI. This is the shape that keeps a solo project maintainable.
- **Golden tests as the migration contract.** Generating fixtures from the original JavaScript and asserting byte-identical CSV and number-identical analysis is the single best engineering choice in the repository. It turns a risky rewrite into a checkable one.
- **Protocols only at real seams.** Repository, timer, exporter, weather, HTTP, notifications, lifecycle. Nothing is abstracted on speculation. The reference blueprint supplied has far more ceremony for far less reason.
- **The aggregate.** `RoundSession` captures the range flow, the quota rule, NO TARGET and undo as a pure value type with tests. That is the piece most apps get wrong by letting the view own it.

## What is weak or missing

- **Nothing compiles yet.** Hand review of 4,700 lines across SwiftData macros, `@Observable`, `#Predicate`, and `MainActor.assumeIsolated` will not catch everything. Expect a round of compile fixes on the Mac. This is normal, but it must happen before Phase 5, or errors compound.
- **Test coverage is uneven.** TrapCore is well covered. ShotTimer, TrapDesign and TrapReports have no tests at all. ShotTimer is defensible since its logic is the untouched detector, but the scorecard renderers and the exporter template method deserve at least a smoke test in the simulator.
- **The app target is still the hybrid app.** The packages are not referenced from the Xcode project. Wiring local packages into a hand-maintained project file is the next concrete step and the one most likely to need Xcode itself rather than a text editor.
- **The detector regression set does not exist.** Every rule in the repository says the detector may not change without it, yet Phase 4 cannot start until the nine range videos and the mic test are turned into fixture files with expected times. That is work only the owner can supply.
- **Documentation outruns code.** Thirteen documents for an app with no native screen is heavy. The documents are good, but from here each new document should be paid for by a shipped screen.
- **Two design debts introduced during this work.** First, the `@MainActor` on the exporter protocol forces CSV and backup exports onto the main actor; it is correct for now and simple, but a large CSV should move off the main actor before Phase 6. Second, V1 of the schema already has a migration to V2 before any user has a V1 store; harmless, but it means a migration path is being maintained for a store that does not exist in the wild. Collapsing to a single V1 before the first TestFlight build is cleaner.

## Risks, in order

1. Compile and runtime surprises in SwiftData and Observation code written blind.
2. The project file edit for package references breaking the baseline build.
3. Receiver behaviour on device differing from the simulator, which no test here can show.
4. Scope drift toward sync and coach features before Phase 8.

## What to do next, in order

1. Connect GitHub, push, and run the first `swift test` on the Mac for TrapCore, TrapData and TrapWeather. Fix until green. Do nothing else until this is done.
2. Open TrapDesign and TrapReports in Xcode and render the component preview and the scorecard. Fix until they draw.
3. Add the package references to the Xcode project and build the hybrid app with the packages linked but unused, to prove the project file.
4. Record the detector regression fixtures from the range videos and run them through the detector.
5. Only then start Phase 5, the Record and Timer screens.

## Repository facts behind this evaluation

| Package | Source lines | Test lines | Depends on |
|---|---:|---:|---|
| TrapCore | 1,407 | 543 | nothing |
| ShotTimer | 948 | 0 | nothing (detector and recorder unchanged) |
| TrapDesign | 664 | 0 | nothing |
| TrapPlatform | 531 | 74 | nothing |
| TrapData | 448 | 112 | TrapCore |
| TrapReports | 377 | 0 | TrapCore, TrapData, TrapDesign |
| TrapWeather | 303 | 148 | TrapCore |

Hybrid app target: 1,060 lines of Swift plus the 3,525-line web page. Documentation: 1,288 lines across 13 files. Golden fixtures: 384 KB in 5 files.

---

The independent reviewer's findings and their status: `docs/code-review-2026-10-22.md`.
