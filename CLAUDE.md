# TrapShooterPro

Native iOS/iPadOS app for Olympic Trap shooters: a call‑to‑shot timer that listens through the microphone,
a 25‑target round recorder, break‑distance model, analysis and exports. **Local‑first: no account, no server, no network
dependency.** Icon label "TrapShoot", bundle id `com.mtajudeen.trapshooterpro`, iOS 17.0+, iPhone and iPad, SwiftUI.

Read `docs/phases/README.md` (master plan by phase, exit gates), `docs/architecture-review.md` and
`docs/code-review-2026-10-22.md` (evaluation and the fixed findings), `docs/build-options.md` (how to compile without a local Mac), `docs/native-plan.md` (decisions), `docs/architecture.md`
(system design, ADRs), `docs/engineering.md` (testing, security, performance, debugging, git, CI) and
`docs/design-system.md` (visual system, breakpoints) before larger changes.

## State of the migration

The 7.0.7 hybrid app (a 3,500‑line web page in a `WKWebView`, Supabase account) has been replaced by 100 % Swift. The
app target only starts `TrapAppRoot` from `Packages/TrapApp` (ADR‑017). The web page survives only as the frozen golden
reference in `Tools/golden/reference/`; it is never shipped or extended. Progress per deliverable: `docs/progress.md`.

| Layer | Path | Status |
|---|---|---|
| App target | `TrapShooterPro/` | `@main` entry, assets, privacy manifest; links `TrapApp` |
| Screens, view models, timing flow | `Packages/TrapApp` | written: Record, Timer, Rounds, Analysis, Schemes, Settings; `TimingFlow` ports the 7.0.7 range flow; `RecordFlowTests` |
| Shot detector, mic engine, recorder | `Packages/ShotTimer` (detector and recorder are the validated 7.0.7 sources, unchanged; `TimerSession` replaced `MicBridge`) | written, tested in CI; device checks pending |
| Pure logic | `Packages/TrapCore` | written, golden‑tested against the JavaScript (incl. trap analysis) |
| Design system | `Packages/TrapDesign` | written |
| Storage (SwiftData) | `Packages/TrapData` | written: `RoundRepository`, in‑memory and SwiftData, summaries with search and paging, transactional `saveMany`, backup, importer |
| Reports (scorecard PNG, PDF, CSV share) | `Packages/TrapReports` | written: `DocumentExporter` + factory, `ScorecardView`, PNG and vector PDF exporters |
| Weather + location | `Packages/TrapWeather` | written: Open‑Meteo client tuned for constrained networks, sky/wind mapping, fill policy, one‑shot location |
| Platform (lifecycle, power, network, notifications, storage, identity) | `Packages/TrapPlatform` | written; policies in `docs/architecture.md` ADR‑010..013 |
| Publishing | `TrapShooterPro/PrivacyInfo.xcprivacy`, `ExportOptions.plist`, `Scripts/archive.sh`, `docs/app-store.md` | written |
| 7.0.7 web page | `Tools/golden/reference/index-7.0.7.html` | frozen reference for the golden fixtures and for behaviour; not in the app |

## Architecture

- **One app target, local Swift packages.** Pure logic has no UIKit/AVFoundation imports so it is unit‑testable anywhere.
- **TrapCore** owns the domain: `RoundSession` (the aggregate: phase setup → recording → complete, entry with the
  station‑quota guard, NO TARGET, bounded undo), `Round` (value type, 25 targets), `Direction` (R/S/L), `TargetResult` (G hit 1st, Y hit 2nd,
  R lost), `Schemes` (10 ISSF schemes × 15 machines), station rule and prediction (`RoundRules`), `SessionID`,
  `RoundDocument` (document v2 JSON, tolerant import = the web app's `norm`, export = `toDoc`), `BreakDistanceModel`,
  `CSVExport`, `Analysis`. Station, machine, angle, height and break distance are **derived**, never stored.
- **ShotTimer** wraps `AudioDetector` unchanged. `TimerSession` (`@Observable`) replaced `MicBridge` and publishes the
  same events the page received: started, inputs, route, restarted, error, first, target, reject, level, diag, saved.
  "Time a recording" (to come with the regression set) feeds an audio file through the same detector.
- **TrapApp** holds the screens and `@Observable` models (`AppModel`, `RecordModel`, `RoundsModel`, `WeatherModel`) and
  `TimingFlow`, the pure port of the page's live timing. The app target holds only `TrapShooterProApp.swift`.
- **TrapData** holds SwiftData models mirroring `Round`, autosave on every entry, a full‑library JSON backup/restore and a
  one‑time importer for 7.x documents. Recordings stay in `Documents/Recordings` so the Files app shows them.
- **UI**: `TabView` on iPhone (Record, Timer, Rounds, Analysis, Schemes, Settings), `NavigationSplitView` with an ink
  sidebar on iPad. Views are thin; logic lives in TrapCore and `@Observable` models. Everything styled with `TrapDesign`
  tokens (`BW.*`, `BWFont`, `BWMetrics`, `.bwCard()`, `.bwPrimary` …). No hard‑coded colours, sizes or fonts in views.
- **Interchange stays compatible**: document v2 JSON and the CSV column layout are the export formats. Changing them
  breaks the coach's tooling and the golden tests.

## Rules

1. **Never change `AudioDetector.swift` detection logic** without a fixture‑based regression run (range recordings with
   expected call/shot times). Timing is measured in samples on the audio thread; keep it there. The audio session is set
   once in `start` and never re‑applied while timing runs.
   **Reference receiver: DJI Mic Mini 2** (transmitter on the shooter, receiver plugged into the iPhone); the phone mic is
   the fallback. Design and verify timer work for it first. Receiver behaviour lives in `TimerSession`/`TimerTypes`, not
   in the detector: `ReferenceReceiver` recognises it by a port name containing "DJI", System default prefers it over
   other external inputs (a shooter's explicit pick always wins), and `AudioDiagnostics.line` names it on the audio
   check line.
2. **Golden tests gate TrapCore.** Any change to rules, schemes, codec, break distance, CSV or analysis must keep
   `swift test` green against `Packages/TrapCore/Tests/TrapCoreTests/Fixtures`. Regenerate fixtures only when the
   JavaScript reference itself changes: `node Tools/golden/generate.js Tools/golden/reference/index-7.0.7.html Packages/TrapCore/Tests/TrapCoreTests/Fixtures`.
3. **No accounts, no network at launch.** No sign‑in, no analytics, no third‑party SDKs. The only network call is the
   optional Open‑Meteo weather fill through `TrapWeather`, gated by `NetworkMonitor` (no automatic fetch in Low Data
   Mode), and the app must work with it failing. No remote push; local notifications only, permission never at launch.
   The timer stops when the app goes to background; there is no background audio mode (ADR‑010).
4. **Design system only.** Use `TrapDesign` tokens and components; light and dark must both look right; Dynamic Type;
   44 pt minimum tap targets; respect Reduce Motion.
5. **Olympic Trap facts are fixed**: 25 targets, 5 stations, order 3‑4‑5‑1‑2 from the chosen start station, each station
   gets 2 right, 1 straight, 2 left; results G/Y/R; direction codes R/S/L. Do not "simplify" these.
6. **Keep the range flow**: call and shots → direction and result → arm the next target and reset to 0.000. Shots fired
   while a result is being entered are ignored. Skip, Re‑time, Undo and NO TARGET must keep their 7.0.7 meaning.
7. **Privacy strings** in the project (microphone, location) are user‑facing; keep them accurate when behaviour changes.
8. **Settings in code, not asset catalogs** for colours (dynamic tokens in `BWColor.swift`), so they are testable and greppable.
9. **Swift style**: Swift 5.9+, `@Observable`, async/await, value types for domain data, `Sendable` where cheap,
   no force‑unwraps outside tests, doc comments on public API in the packages.
10. **Commits**: small, one topic, imperative subject, body says why. Never commit secrets. The old Supabase anon keys left with the Web
    folder (Phase 7). Workflow in `docs/git-workflow.md`; CI in
    `.github/workflows/ci.yml` must be green before merging.
11. **Errors the shooter sees conform to `UserFacingError`** (TrapCore). No `localizedDescription` on screen. Expected
    conditions (no weather, no receiver) are states with a line of text, not alerts. Imports sanitise, then report.
12. **Validate at the boundaries.** Anything entering from a file, a backup or the network goes through
    `Validation.sanitized` and `Validation.issues`; CSV cells are formula‑safe; file names are stripped. See `docs/security.md`.
13. **Log with `TrapLog`**, round data as `privacy: .private`; add a signpost when touching anything with a budget in
    `docs/performance.md`. No third‑party analytics or crash SDKs: MetricKit and the support bundle cover it.
14. **Queries, not full loads, for lists.** `fetchSummaries` (columns, filter, paging) for the Rounds list;
    `fetchAll` only for Analysis and exports; `saveMany` for anything that writes more than one round.

## Build, test, run

```sh
# pure logic, fastest loop (Mac or Linux with a Swift toolchain)
cd Packages/TrapCore && swift test

# app (Mac)
xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# unit tests of all packages through the app scheme once they are linked
xcodebuild -project TrapShooterPro.xcodeproj -scheme TrapShooterPro \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Scheme: `TrapShooterPro`. Project: `TrapShooterPro.xcodeproj` (no workspace yet; packages are added as local package
references). The microphone, external receivers and timing accuracy can only be verified on a real device.

## Xcode tooling for Claude (Mac only)

`.mcp.json` registers two MCP servers for sessions opened on the Mac:

- **XcodeBuildMCP** (`npx -y xcodebuildmcp@latest mcp`): discover projects and schemes, build, run tests, boot a simulator,
  install and launch the app, read logs, capture screenshots, UI automation. Prefer it over raw `xcodebuild` for
  build‑fix loops.
- **Xcode's own MCP bridge** (`xcrun mcpbridge`, Xcode 26.3+): needs Xcode running with this project open and
  *Settings → Intelligence → Allow external agents to use Xcode tools* enabled. Gives live diagnostics, builds and tests
  inside Xcode, and **SwiftUI Preview rendering** (`RenderPreview`) so the design system can be checked visually.

Setup steps are in `docs/mac-setup.md`. Neither server works in Linux cloud sessions; there, edit and reason, and leave
compile verification to the Mac session.

## Working agreements for Claude sessions

- Before editing a screen, read the matching section of the 7.0.7 page (`Tools/golden/reference/index-7.0.7.html`) to preserve
  behaviour, then write it natively; do not port HTML or CSS literally.
- When porting a JavaScript function into TrapCore, add it to `Tools/golden/generate.js` and a test first.
- After any change in `Packages/`, run `swift test` (Mac) or say explicitly that it was not compiled.
- Report test output faithfully; a failing golden test means the Swift is wrong, not the fixture.
