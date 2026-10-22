# TrapShooterPro architecture

System design of the native app, with the decisions that shaped it. Companion to `docs/native-plan.md` (what and when)
and `docs/design-system.md` (how it looks). `CLAUDE.md` carries the rules in short form.

## 1. Context

One shooter, one device, on a trap range with poor signal. The app must time calls and shots to the millisecond, record
25 targets without slowing the squad, and keep every round the shooter ever recorded. There is no server and no account.

```
┌─────────────┐  sound   ┌──────────────────────────────────────────────────────┐  files   ┌───────────┐
│ Shooter,    │ ───────▶ │ iPhone / iPad                                        │ ───────▶ │ Files app │
│ gun, DJI    │          │  mic / receiver → ShotTimer → Record screen → TrapData│  share   │ AirDrop   │
│ receiver    │ ◀─────── │  readout, haptics, scorecard, CSV, PDF, backup       │ ───────▶ │ Mail      │
└─────────────┘  screen  └──────────────────────────────────────────────────────┘          └───────────┘
                                             │ optional, failure tolerated
                                             ▼
                                     Open‑Meteo (weather fill)
```

## 2. Modules and dependencies

Dependencies point downwards only. Nothing below the app target imports SwiftUI except `TrapDesign`.

```
TrapShooterPro (app)  ──▶  TrapDesign (SwiftUI tokens, styles)
        │
        ├──▶ ShotTimer   (AVFoundation)        ──▶ (no TrapCore dependency: ms in, ms out)
        ├──▶ TrapData    (SwiftData)           ──▶ TrapCore
        ├──▶ TrapReports (CoreGraphics, PDF)   ──▶ TrapCore, TrapDesign
        ├──▶ TrapWeather (CoreLocation, URLSession) ──▶ TrapCore
        ├──▶ TrapPlatform (UIKit, Network, UserNotifications)
        └──▶ TrapCore    (Foundation only)
```

| Module | Responsibility | Key types | Tests |
|---|---|---|---|
| TrapCore | domain model, rules, maths, interchange | `Round`, `Direction`, `TargetResult`, `Schemes`, `RoundDocument`, `BreakDistanceModel`, `CSVExport`, `Analysis`, `TrapAnalysis` | golden fixtures from the JavaScript |
| ShotTimer | microphone, detection, recording | `AudioDetector` (unchanged), `RoundRecorder` (unchanged), `TimerSession`, `TimerEvent`, `ShotTimerControlling` | detector regression fixtures (range recordings) |
| TrapData | persistence, backup, import | `RoundRepository`, `InMemoryRoundRepository`, `SwiftDataRoundRepository`, `RoundRecord`, `Backup`, `Importer` | in‑memory and in‑memory‑SwiftData tests |
| TrapDesign | visual system | `BW`, `BWFont`, `BWMetrics`, `BWMotion`, components | preview |
| TrapReports | scorecard PNG, A4 PDF, share items | planned | snapshot |
| TrapWeather | one‑shot location, Open‑Meteo, sky/wind mapping, fill policy | `WeatherService`, `OpenMeteoClient`, `WeatherSample`, `WeatherFill`, `LocationOnce` | mapping, policy, URL and parsing tests |
| TrapPlatform | lifecycle, power, network, local notifications, storage, identity | `LifecycleCoordinator`, `PowerMonitor`, `NetworkMonitor`, `LocalNotifier`, `RecordingsStore`, `StorageReport`, `AppInfo` | pure parts tested; monitors verified on device |

## 3. Object model

Three kinds of types, chosen on purpose:

- **Values** for data that is copied, compared and stored: `Round` and everything in TrapCore. Equality is structural,
  so "did the round change" is `!=`, undo is "keep the previous value", and tests compare whole rounds.
- **Observable reference types** for things with a lifetime and identity: `TimerSession` (owns the audio engine),
  repositories (own a store), screen models. They are `@MainActor`; UI reads them directly.
- **Protocols at module boundaries** where a second implementation is real, not hypothetical:
  `RoundRepository` (SwiftData on device, dictionary in tests and previews, import preview),
  `ShotTimerControlling` (the real session, a scripted session for previews and UI tests, later the file analyser).
  No protocol is introduced for a type with one implementation.

Encapsulation that matters:

- `AudioDetector` and `RoundRecorder` are **internal** to ShotTimer. The app never touches the audio engine; it talks to
  `TimerSession` and receives `TimerEvent`s. The detector's `Config` is wrapped by the public `TimerSettings`.
- `RoundRecord` (SwiftData) is an implementation detail of TrapData. The rest of the app only ever sees `Round`.
- Derived facts (station, machine, angle, height, break distance, score) are **computed**, never stored, so they can
  never disagree with the targets they come from.

## 4. Data structures and algorithms

| Where | Structure / algorithm | Why |
|---|---|---|
| `AudioDetector` | ring buffers (10 ms RMS windows), running sums, biquad filters, 0.3 s history ring, lock‑protected state, zero allocation in the audio callback | real‑time: the audio thread must never block or allocate |
| `AudioDetector` | look‑back candidate list (calls within 0.15–2.0 s before a shot), 5 ms confirmation window, echo tail rule | timing from samples, not timers, so device latency cancels |
| `Round` | fixed 25‑slot arrays indexed by target | O(1) access, the document shape, no sparse maps |
| `RoundRules` | station counts per direction, quota arithmetic | O(25) per query, no caching needed |
| `SessionID` | deterministic base + collision suffix | human‑readable ids, no UUIDs on the scorecard |
| `BreakDistanceModel` | 80‑entry shot flight table (Euler integration with drag), then fixed‑point iteration (30 steps) to find where shot meets clay | table built once per settings; iteration converges in a few steps |
| `Analysis.tables` | one pass per dimension, dictionary aggregation, ordered emission | O(rounds × 25 × dimensions) |
| `TrapAnalysis` | per‑trap aggregation, median outlier filter (sort once), **3×3 least squares** (normal equations + Gaussian elimination with partial pivoting), residual bands | small, exact, matches the web app bit for bit |
| `SwiftDataRoundRepository` | indexed columns + JSON document payload | list queries hit columns; the payload keeps the interchange shape |
| `Importer` | recursive walk over unknown JSON, id de‑duplication with a set | accepts every shape the old app produced |

Complexity is never the constraint here (a lifetime of rounds is thousands, not millions); **determinism and
reproducibility are**. Hence golden tests against the JavaScript and `JSText.number` for byte‑identical CSV.

## 5. Runtime: threads and data flow

```
audio thread            main actor                              SwiftData
───────────            ───────────                              ─────────
AVAudioEngine tap ──▶ AudioDetector.process (lock)
                       └─ posts closures ──▶ DispatchQueue.main ──▶ TimerSession.emit(TimerEvent)
                                                                   │
                                                 RecordModel observes TimerSession
                                                 ├─ firstShot → readout shows t1
                                                 ├─ target → round.firstShot[i], secondShot[i], callLevel[i]
                                                 ├─ shooter taps direction + result → round.results[i]
                                                 └─ repository.save(round) ──────────────────────▶ RoundRecord
                                                 SwiftUI re-renders from the value
```

- Only the audio thread touches the detector's state; it hands results to the main actor as closures.
- `TimerSession` is `@MainActor`; callbacks arriving on the main queue use `MainActor.assumeIsolated`.
- Writes are small and frequent (one per target). `save` replaces the whole document; there is no partial update.
- `RoundRecorder` writes AAC on its own serial queue; disk full never stops timing.

## 6. Persistence design (ADR‑003, ADR‑004)

- Store: SwiftData, one entity `RoundRecord`, in the app's Application Support directory, included in iPhone backups.
- Payload: document v2 JSON, the same bytes the Backup file and the CSV companion use. Lists read columns
  (`date`, `scheme`, `score`, `recorded`, `sessionId`); detail reads the payload.
- Recordings: `Documents/Recordings/*.m4a` plus a `.json` sidecar with the timer settings, visible in the Files app.
- Settings: `UserDefaults` through `@AppStorage`, keyed as the 7.x page keyed them where it helps migration.
- Backup/restore: `Backup.encode` writes one file; `Importer` reads that file, a Supabase table export, or the 7.x
  browser cache and pending queue, so nothing a shooter has today is lost.

## 7. Failure handling

| Failure | Behaviour |
|---|---|
| Receiver unplugged | route change → event → screen says so; timing stops only if the engine stops |
| Engine stops after a hardware change | rebuild after 0.3 s, keep recording if the sample rate held |
| No audio for 1.5 s | watchdog restarts up to 3 times, then a plain‑language note |
| Phone call, Siri, alarm | timing stops, message asks to tap Start again |
| Microphone permission off | message with the Settings path |
| Disk full while recording | timing continues, recording ends silently |
| Weather unavailable | fields stay editable, no error dialog |
| Corrupt document in the store | row skipped on list, never a crash; import reports skipped rows |

## 8. Architecture decision records

**ADR‑001 Local‑first, no account.** The shooter's device is the source of truth. No sign‑in, no server, no network at
launch. Consequence: backup/restore and device backups carry the data; sharing is by file. Supersedes the 7.x Supabase
design. Reason: App Review 5.1.1(v), range connectivity, privacy labels.

**ADR‑002 Keep the detector byte for byte.** `AudioDetector.swift` and `RoundRecorder.swift` are moved, not rewritten.
Public access is added around them, never inside. Reason: validated on range recordings; the rest of the app is cheap
to rebuild, this is not.

**ADR‑003 SwiftData with a document payload.** Columns for lists, JSON for the round. Reason: zero migration risk for
the target arrays, one shape for store, backup and import, SwiftData's `@Query` for free in lists. Alternative rejected:
fully normalised `Target` rows (25 rows per round, no benefit, migrations on every field change).

**ADR‑004 Document v2 and the CSV layout are frozen interchange formats.** Golden tests pin them. Reason: coach tooling
and the shooter's existing data.

**ADR‑005 Protocols only at real seams.** `RoundRepository`, `ShotTimerControlling`. Everything else is concrete.
Reason: previews, tests and the import preview need second implementations; nothing else does.

**ADR‑006 No WebView, no JavaScript.** The page is reference material until Phase 2 deletes it. Reason: App Review 4.2,
accessibility, dark mode, performance, one language.

**ADR‑007 Design tokens in code.** Colours, fonts, metrics are Swift constants in `TrapDesign`, not asset catalogs.
Reason: greppable, testable, dark mode in one place, no Xcode‑only edits.

**ADR‑008 iOS 17 minimum, universal.** `@Observable`, SwiftData, `ShareLink`, `ImageRenderer`. iPad gets a split view.

**ADR‑009 Main‑actor UI state, audio thread detection, serial recorder queue.** Three concurrency domains, fixed
hand‑off points (`DispatchQueue.main` posts, `MainActor.assumeIsolated`), no shared mutable state elsewhere.

**ADR‑010 Lifecycle: no background audio.** On `background` the timer stops and the recording closes inside a short
background task; on `inactive` the round is saved and timing continues; on foreground the inputs refresh and the
shooter is told the timer stopped. Reason: a microphone that listens while the app is hidden is a privacy and battery
problem and would need a background mode we cannot justify to review. `TrapPlatform.LifecycleCoordinator`.

**ADR‑011 Local notifications only.** No server, so no remote push, no APNs token, no notification permission at
launch. One reminder exists: an unfinished round, scheduled when the app goes to background mid‑round, cancelled when
the round completes, permission asked at that moment. `TrapPlatform.LocalNotifier`.

**ADR‑012 Power and network are inputs, not afterthoughts.** `PowerMonitor` turns battery, Low Power Mode and thermal
state into one advice value the Timer screen obeys (slower level meter, round audio off by default, warning under 10 %).
`NetworkMonitor` gates the only network call: automatic weather fill needs a reachable, unconstrained path; Low Data
Mode disables automatic fetches; the URLSession never waits for connectivity, never caches, and times out at 15 s.

**ADR‑014 No backend, so no auth, GraphQL or sockets.** The app's one network call is an unauthenticated REST GET to a
public weather API through `HTTPClient` (typed endpoint, transient‑only retry, stub‑tested). Sharing with a coach, when
it comes, is a file the shooter sends or a signed expiring link; never a login. Reason: nothing to protect server‑side,
nothing to leak client‑side, no token lifecycle to get wrong.

**ADR‑015 CI gates every change to main.** Fixtures must match the JavaScript, `swift test` must pass for the pure
packages on macOS, the app and iOS‑only packages must build and test in the simulator. TestFlight uploads are a manual
workflow. No Docker: iOS builds need macOS runners. Reason: the golden tests are only worth something if they run.

**ADR‑016 Diagnostics without SDKs.** `os.Logger` with privacy annotations, signposts for the performance budgets,
MetricKit for crashes, hangs and energy, and a text support bundle the shooter mails. Reason: no third‑party code, no
data leaves the device unless the shooter sends it, and Apple's tools read all of it.

**ADR‑013 Publishing artifacts live in the repository.** Privacy manifest, export options, archive script, review
notes and listing text are versioned next to the code (`docs/app-store.md`), so a release is reproducible by anyone
with the Mac and the team id.

**ADR‑017 The UI is a package; the app target only starts it.** Screens, view models and the timing flow live in
`Packages/TrapApp`, which depends on the other seven packages; the app target holds `TrapShooterProApp.swift` and links
the one product through an `XCLocalSwiftPackageReference`. Reason: a hand‑maintained `project.pbxproj` needs one entry
instead of one per file, the UI compiles and tests in CI like any package (`xcodebuild -scheme TrapApp test`), and the
hybrid sources leave the target in one edit. Consequence: `public` on what the app target touches (`TrapAppRoot`
only); everything else stays internal and `@testable`.
