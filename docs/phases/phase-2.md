# Phase 2 — Pure domain core `[OOP · DSA · SEF]` — done, first `swift test` on the Mac pending

`Packages/TrapCore`: Foundation only. Ports of every pure function of the web page with golden fixtures.

| Area | Types | Golden fixture |
|---|---|---|
| Model and rules | `Round`, `Direction`, `TargetResult`, `RoundRules`, `SessionID` | `rounds.json`, `sessions.json` |
| Schemes | `Schemes`, `TrapMachine` | `schemes.json` |
| Interchange | `RoundDocument` (tolerant import, export) | `rounds.json`, `norm.json` |
| Ballistics | `BreakDistanceModel`, `BreakSettings`, `ShotSize` | `break.json` |
| Export | `CSVExport`, `JSText` | `rounds.json` (byte for byte) |
| Analysis | `Analysis`, `TrapAnalysis` (least squares, findings) | `rounds.json`, `analysis.json` |
| Lifecycle | `RoundSession` (state machine, undo, NO TARGET, quota guard) | unit tests |
| Boundaries | `Validation`, `UserFacingError`, `DisplayError` | unit tests |
| Budgets | analysis, CSV and codec `measure` tests | — |

**Exit gate:** `swift test --package-path Packages/TrapCore` green on the Mac; test time under 10 s; `grep -r "import
UIKit\|import SwiftUI\|import SwiftData" Packages/TrapCore/Sources` empty. Property‑style checks worth adding on the Mac:
document round trip for random rounds; `isFull` never allows a station past 2/1/2.
