# TrapShooterPro — Master implementation plan, by phase

The six pillars of the reference blueprint, translated to a native, local‑first iOS app, and the phases that deliver
them. Every phase has an exit gate that is checked on a real iPhone, not only in the simulator.

| Pillar | Symbol | In this app |
|---|:---:|---|
| Object‑oriented programming | `[OOP]` | value types for domain data (`Round`, `TrapMachine`, `BreakSettings`), one aggregate with a state machine (`RoundSession`), protocols only at real seams (`RoundRepository`, `ShotTimerControlling`, `DocumentExporter`, `WeatherService`, `HTTPClient`, `LocalNotifying`), a polymorphic exporter hierarchy with a factory |
| System design | `[SD]` | local‑first, the device is the only source of truth; no outbox, no sync, no cloud replica (ADR‑001); three concurrency domains (audio thread, main actor, recorder queue); document‑payload store with indexed columns |
| Data structures and algorithms | `[DSA]` | ring buffers and running sums on the audio thread; fixed 25‑slot arrays; least squares for trap geometry; fixed‑point iteration for break distance; column fetches, filters and paging for lists; denormalised `score`/`recorded`/`place` columns as the pre‑aggregated summary |
| Core mobile systems | `[CMS]` | SwiftUI + SwiftData, no cross‑platform layer; lifecycle policy (no background audio), power and network monitors, local notifications only, file protection, privacy manifest, TestFlight via `xcodebuild` |
| Software engineering foundations | `[SEF]` | package boundaries enforced by the dependency graph (TrapCore imports nothing), golden tests against the JavaScript, CI gates, user‑facing errors, OWASP Mobile mapping, `os.Logger` + MetricKit |
| Tablet and responsive design | `[TAB]` | `Breakpoint` (phone < 600, 8" 600–1099, large ≥ 1100), `AdaptiveSplit` 40/60 and 35/65, sidebar on iPad, 44/48 pt targets, hardware‑keyboard shortcuts, black‑and‑white tokens with SF |

What the reference has that this app deliberately does not: SQLCipher (iOS file protection instead), Keychain tokens
and biometrics (no accounts), outbox and conflict resolution (no sync), GraphQL/WebSockets/JWT (no backend), Expo CNG
and EAS (Xcode and `xcodebuild`), Sentry (MetricKit and a support bundle), Android (Apple only by decision).

## Phase summary

| Phase | Name | Pillars | Status | Exit gate (one line) |
|:---:|---|---|---|---|
| 0 | Discovery, architecture and decisions | SD · SEF · OOP | **done** | ADR‑001…016 written; plan, design system and engineering docs in the repo |
| 1 | Foundation, tooling, design tokens | CMS · SEF · TAB | **done** (verification on Mac pending) | baseline 7.0.7 builds; CI green; `TrapDesign` preview renders light and dark; breakpoints published |
| 2 | Pure domain core | OOP · DSA · SEF | **done** (first `swift test` on Mac pending) | all golden fixtures pass; `RoundSession` tests pass; zero UI or storage imports in TrapCore |
| 3 | Local store and repositories | SD · DSA · CMS · SEF | **done** (verification on Mac pending) | summaries, search, paging and `saveMany` rollback tests green; import of 7.x shapes |
| 4 | Shot timer engine | OOP · CMS · DSA | package written; device verification pending | detector regression set within 7 ms on every fixture; receiver plug/unplug recovers; watchdog restarts; 1 h timing < 10 % battery |
| 5 | Record and Timer screens | OOP · CMS · TAB · SEF | next | a full round recorded on a real range with the native app; kill‑and‑resume restores the round; iPad split layout verified |
| 6 | Rounds, Analysis, Schemes, exporters | DSA · TAB · SEF | after 5 | 2,000‑round list first screen < 50 ms; scorecard PDF text is selectable; CSV byte‑identical to the web app for the same round |
| 7 | Settings, data, platform behaviours | CMS · SD · SEF | after 6 | backup/restore round‑trips the library; lifecycle, notifications, power and network policies observed on device; Web folder deleted |
| 8 | Release engineering and App Store | CMS · SEF | after 7 | TestFlight external beta passed by three shooters; review notes and privacy answers filed; submission accepted |
| 9 | Operate and iterate | all | ongoing | MetricKit crash‑free sessions > 99.5 % over 3 months; support bundles answered; iCloud sync evaluated |

Phase files: `phase-0.md` … `phase-9.md`. Gate record template: `gates/PHASE_GATE_TEMPLATE.md`.

## Cross‑cutting concern matrix

| Concern | Ph0 | Ph1 | Ph2 | Ph3 | Ph4 | Ph5 | Ph6 | Ph7 | Ph8 | Ph9 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| OOP — value types, aggregate, protocols | ● | ○ | ● | ○ | ● | ● | ● | ○ | ○ | ○ |
| OOP — state machine (`RoundSession`) | ● | ○ | ● | ○ | ○ | ● | ○ | ○ | ○ | ○ |
| SD — local‑first, no sync | ● | ○ | ○ | ● | ○ | ● | ○ | ● | ○ | ● |
| SD — concurrency domains | ● | ○ | ○ | ○ | ● | ● | ○ | ○ | ○ | ○ |
| DSA — audio pipeline | ○ | ○ | ○ | ○ | ● | ○ | ○ | ○ | ○ | ○ |
| DSA — queries, paging, summaries | ○ | ○ | ○ | ● | ○ | ○ | ● | ○ | ○ | ○ |
| DSA — analysis maths | ○ | ○ | ● | ○ | ○ | ○ | ● | ○ | ○ | ○ |
| CMS — lifecycle, power, network | ○ | ○ | ○ | ○ | ● | ● | ○ | ● | ○ | ● |
| CMS — storage, privacy manifest | ○ | ● | ○ | ● | ○ | ○ | ○ | ● | ● | ○ |
| SEF — golden and unit tests | ○ | ● | ● | ● | ● | ● | ● | ● | ○ | ○ |
| SEF — CI, release workflow | ○ | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| SEF — security and privacy | ● | ● | ○ | ● | ○ | ○ | ● | ● | ● | ● |
| TAB — breakpoints, split, keyboard | ○ | ● | ○ | ○ | ○ | ● | ● | ● | ○ | ○ |

● primary focus  ○ applied

## Risk register

| Risk | Phase | Likelihood | Impact | Mitigation |
|---|:-:|:-:|:-:|---|
| Detector regresses when moved or wrapped | 4 | Low | Critical | byte‑identical copy, regression fixtures from range recordings, `cmp` in CI |
| Code written without a compiler does not build | 1–7 | High | Medium | small commits, `swift test` on the Mac after every package change, CI on every PR |
| Hand‑edited `project.pbxproj` breaks | 1, 5 | Medium | Medium | changes limited to resources and package references; Xcode re‑sorts; `merge=union` |
| First schema change after TestFlight breaks existing stores | 7+ | Low | High | versioned schemas with a migration plan already in place; add V2 and a lightweight stage, test on a copied store |
| App Review questions the microphone or wants an account | 8 | Medium | Medium | review notes, no login, privacy manifest, demo instructions (say "pull", clap twice) |
| Battery drain during long sessions | 4, 5 | Medium | Medium | `PowerMonitor` advice, screen‑awake only while timing, level meter throttled |
| External receiver behaviour differs per device | 4, 5 | High | Medium | route handling kept from 7.0.4, audio check line, TestFlight with DJI users |
| Scope creep toward sync and coach features | 7, 9 | Medium | Medium | ADR‑001; iCloud evaluated only in Phase 9 as an option |
| iPad layouts break in Split View and Slide Over | 5, 6 | Medium | Low | window‑width breakpoints, `AdaptiveSplit`, tested at 320/600/1100 pt |

## File index

| File | Purpose |
|---|---|
| `docs/phases/README.md` (this file) | master plan by phase |
| `docs/phases/phase-N.md` | each phase: pillars, deliverables and status, tasks, exit gate, how to verify |
| `docs/phases/gates/PHASE_GATE_TEMPLATE.md` | what a signed gate record contains |
| `docs/native-plan.md` | the original migration plan and decisions |
| `docs/architecture.md` | system design and ADR‑001…016 |
| `docs/engineering.md` | testing, security, performance, debugging, git, CI |
| `docs/design-system.md` | tokens, components, breakpoints |
| `docs/app-store.md` | publishing |
| `CLAUDE.md` | rules for every session |
