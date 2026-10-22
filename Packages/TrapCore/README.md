# TrapCore

The pure-Swift heart of TrapShooterPro. No UIKit, no AVFoundation, no storage.

| File | Port of (Web/index.html) |
|---|---|
| `Direction.swift` | `DIROFF`, `DIRNAME`, `ARROW`, result codes G/Y/R |
| `Schemes.swift` | `SCHEME_SRC`, `SCHEMES`, `trapFor` |
| `Round.swift` | the round object, `stnOf`, `newId`, `todayStr`, `nowHM` |
| `RoundRules.swift` | `score`, `counts`, `recorded`, `stationCounts`, `stationOver`, `isFull`, `dirOdds`, `grade`, `predict` |
| `SessionID.swift` | `initials`, `genSid` |
| `RoundDocument.swift` | `toDoc`, `norm` (document v2 JSON, tolerant import) |
| `BreakDistance.swift` | `BRK`, `sphereCd`, `shotTime`, `breakDist`, `brkShot`, `brkFor` |
| `CSVExport.swift` | `csvFor`, `csvCell` |
| `Analysis.swift` | `DIMS`, `statsOf`, `analyse` |
| `TrapAnalysis.swift` | `schemeCounts`, `dominantScheme`, `solve3`, `fitGeometry`, `trapStats`, `trapFindings`, `overviewHtml` (data), `trendHtml` (data), `signedMs` |

## Golden tests

`Tools/golden/generate.js` runs the original JavaScript on fixed inputs and writes
`Tests/TrapCoreTests/Fixtures/*.json`. The tests assert the Swift port gives the same answers.

```sh
node Tools/golden/generate.js TrapShooterPro/Web/index.html Packages/TrapCore/Tests/TrapCoreTests/Fixtures
cd Packages/TrapCore && swift test
```

Run `swift test` on the Mac (or open the package in Xcode and press Cmd‑U).
