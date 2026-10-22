# TrapShooterPro

Native iOS/iPadOS app for Olympic Trap shooters: a call‑to‑shot timer that listens through the microphone,
a 25‑target round recorder, break‑distance model, analysis and exports. **Local‑first: no account, no server, no network
dependency.** Icon label "TrapShoot", bundle id `com.mtajudeen.trapshooterpro`, iOS 17.0+, iPhone and iPad, SwiftUI.

Read `docs/native-plan.md` (plan and decisions), `docs/architecture.md` (system design, ADRs) and `docs/design-system.md`
(visual system) before larger changes.

## State of the migration

The repo is moving from the 7.0.7 hybrid app (a 3,500‑line web page in a `WKWebView`, Supabase account) to 100 % Swift.
Until the native screens land, the Xcode project still builds the hybrid app. Do not extend the web page; new work goes
into the Swift packages and the SwiftUI app target.

| Layer | Path | Status |
|---|---|---|
| App target (SwiftUI) | `TrapShooterPro/` | hybrid shell; being replaced screen by screen |
| Shot detector, mic engine, recorder | `Packages/ShotTimer` (detector and recorder byte‑identical copies of the app files; `TimerSession` replaces `MicBridge`) | written; the app target still uses its own copies until it links the package |
| Pure logic | `Packages/TrapCore` | written, golden‑tested against the JavaScript (incl. trap analysis) |
| Design system | `Packages/TrapDesign` | written |
| Storage (SwiftData) | `Packages/TrapData` | written: `RoundRepository`, in‑memory and SwiftData, backup, importer |
| Reports (scorecard PNG, PDF, CSV share) | `Packages/TrapReports` | planned |
| Weather + location | `Packages/TrapWeather` | written: Open‑Meteo client tuned for constrained networks, sky/wind mapping, fill policy, one‑shot location |
| Platform (lifecycle, power, network, notifications, storage, identity) | `Packages/TrapPlatform` | written; policies in `docs/architecture.md` ADR‑010..013 |
| Publishing | `TrapShooterPro/PrivacyInfo.xcprivacy`, `ExportOptions.plist`, `Scripts/archive.sh`, `docs/app-store.md` | written |
| Legacy web page | `TrapShooterPro/Web/` | reference only; deleted at the end of Phase 2 |

## Architecture

- **One app target, local Swift packages.** Pure logic has no UIKit/AVFoundation imports so it is unit‑testable anywhere.
- **TrapCore** owns the domain: `Round` (value type, 25 targets), `Direction` (R/S/L), `TargetResult` (G hit 1st, Y hit 2nd,
  R lost), `Schemes` (10 ISSF schemes × 15 machines), station rule and prediction (`RoundRules`), `SessionID`,
  `RoundDocument` (document v2 JSON, tolerant import = the web app's `norm`, export = `toDoc`), `BreakDistanceModel`,
  `CSVExport`, `Analysis`. Station, machine, angle, height and break distance are **derived**, never stored.
- **ShotTimer** (to be created) wraps `AudioDetector` unchanged. `MicBridge` becomes an `@Observable TimerSession`
  exposing the same events it sends to the page today: started, inputs, route, restarted, error, first, target, reject,
  level, diag, saved. "Time a recording" feeds an audio file through the same detector.
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
2. **Golden tests gate TrapCore.** Any change to rules, schemes, codec, break distance, CSV or analysis must keep
   `swift test` green against `Packages/TrapCore/Tests/TrapCoreTests/Fixtures`. Regenerate fixtures only when the
   JavaScript reference itself changes: `node Tools/golden/generate.js TrapShooterPro/Web/index.html Packages/TrapCore/Tests/TrapCoreTests/Fixtures`.
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
10. **Commits**: small, one topic, imperative subject, body says why. Never commit secrets. The old Supabase keys in
    `Web/config.js` are public anon keys and go away with the Web folder.

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

- Before editing a screen, read the matching section of the 7.0.7 page (`TrapShooterPro/Web/index.html`) to preserve
  behaviour, then write it natively; do not port HTML or CSS literally.
- When porting a JavaScript function into TrapCore, add it to `Tools/golden/generate.js` and a test first.
- After any change in `Packages/`, run `swift test` (Mac) or say explicitly that it was not compiled.
- Report test output faithfully; a failing golden test means the Swift is wrong, not the fixture.
