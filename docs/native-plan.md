# TRAP SHOOTER PRO → 100% native Apple app (local‑first, App Store next)

Discussion and plan, based on a full read of `TrapShooterPro-iPhone_ver7.0.7.zip`.

---

## 1. What the project is today

**A hybrid "wrapper" app.** A thin native shell hosts a single‑file web app in a `WKWebView`.

| Layer | Size | Owns |
|---|---|---|
| Swift (native) | ~1,060 lines, 6 files | Microphone, audio engine, **shot detector v3.1**, round audio recording (.m4a), one‑off location, share sheet, JS alert/confirm bridging, link handling |
| Web (`Web/index.html`) | 3,525 lines, 514 KB, plus a 218 KB Supabase JS client | **Everything else**: all UI (6 tabs + hidden Admin), app state, round data model, Supabase sign‑in / sign‑up / password reset, round storage, offline cache + pending‑upload queue, analysis, 10 ISSF trap schemes, break‑distance ballistics, scorecard image, hand‑rolled PDF, CSV export, Open‑Meteo weather, a second JavaScript copy of the shot detector (used for "Time a recording" and for browsers) |

The page is the same PWA that runs on GitHub Pages; the iOS app only replaces the browser microphone with a native one. The README says it so: "To update it, replace `Web/index.html` and press Run. No Swift changes are needed."

**The native part that matters most is finished and good.** `AudioDetector.swift` is a careful, real‑time, lock‑protected detector that runs on the audio thread, validated against 9 range videos and the 18 Oct mic test (every 1st shot within 7 ms, calls within 3 ms). `MicBridge.swift` handles DJI receivers, route changes, interruptions, a watchdog and restarts. `RoundRecorder.swift` writes AAC on a background queue. These three files should be **kept, not rewritten**.

**Feature inventory** (what a native rewrite must reproduce):

- **Record tab**: range data (date, time, session, type, scheme 1–10, field, place), conditions (sky, wind, temp, humidity, auto‑filled from location + Open‑Meteo), 25‑target entry (station 1–5, direction L/S/R, result G/Y/R = hit 1st barrel / hit 2nd barrel / lost), direction quota prediction, Skip, Re‑time, Undo, **NO TARGET** counter, scorecard, targets ledger, done card, share panel.
- **Timer tab**: start/stop, input picker (phone mic vs DJI/Lark receiver, "System default" prefers external), audio‑in diagnostic line, live level meter, rejected‑sounds log, timer settings (call dB, shot dB, echo ms, offset, min call ms, 2nd‑shot window, call gate), **Break distance** model (release delay, clay speed, shot V1, shot size, with scheme angle/height and air drag), round audio record + share, "Time a recording" (offline analysis of an audio file), tap and beep arming modes.
- **Rounds tab**: list, open, delete, per‑round exports.
- **Analysis tab**: overview tiles, trend, 8 dimensions (direction, station, angle band, height band, position in round, scheme, sky, wind), per‑scheme trap analysis with a least‑squares geometry fit and plain‑language findings.
- **Schemes tab**: ISSF scheme table (10 schemes × 5 stations × 3 machines: side, angle, height).
- **Profile**: name, DOB, weapon, ammo, chokes, password change, account delete, consent text.
- **Admin (hidden)**: Capri Studio view of all shooters and rounds, group analysis, CSV export.
- **Exports**: CSV (one row per target, ~45 columns incl. `break_m`, `no_target`), scorecard PNG, PDF.
- **Data**: round document v2 (JSON), stored in Supabase `rounds.doc`, cached in `localStorage`, with a pending‑upload queue for offline saves.

**Project settings**: iOS 16.0 minimum, iPhone only, portrait only, light mode forced, bundle id `com.mtajudeen.trapshooterpro`, display name "Shooter Pro", version 7.0.7 (build 7), mic and location usage strings present, file sharing on. **Never compiled** (README: "built on a computer without Xcode").

---

## 2. Why the current form will struggle on the App Store

1. **Login wall.** The app shows a sign‑in screen at boot and will not time or record anything without a Supabase account (and an email consent to let Capri Studio view your rounds). App Review guideline 5.1.1(v) says an app may not require an account for features that do not need one. Timing a round needs no account. This is the most likely rejection reason.
2. **Web wrapper risk (guideline 4.2).** Review looks for apps that are "a web site bundled as an app". The native microphone makes this defensible, but the whole visible UI is HTML with web controls, forced light mode, fixed 14 px text (no Dynamic Type), no native accessibility, no native navigation. It reads as a web page.
3. **Offline is partial.** Cached rounds and the pending queue exist, but boot still waits on the network (8 s timeout) and a new user cannot start at all offline. Trap ranges often have poor signal.
4. **Privacy obligations are heavier than needed.** Email + password, DOB, consent to third‑party viewing, all stored on a server. That means a privacy policy URL, App Privacy "nutrition labels" declaring collected data, and a visible account‑deletion flow (exists, good). A local‑first app declares almost nothing.
5. **Distribution.** The free Personal Team install lasts 7 days. TestFlight and the App Store need the paid Apple Developer Program (US$99/year).
6. **Two detectors.** The JavaScript detector in `index.html` duplicates the Swift one and can drift from it (the README's version history shows the Swift one moving ahead).

None of these are blockers for a rewrite. They are the reasons to do it.

---

## 3. What "100% Apple, local‑first" means here

**Proposed definition**

- **Swift and SwiftUI everywhere.** No `WKWebView`, no JavaScript, no bundled web folder, no Supabase client in the app.
- **The phone is the source of truth.** All rounds, settings and audio live on the device in a real database (SwiftData on SQLite). Everything works with Airplane Mode on, forever, with no account.
- **Cloud is optional and additive.** Sync and sharing are features added later, never a requirement to open the app.
- **Interchange stays compatible.** The existing round document v2 JSON and the CSV layout are kept as the export/import format, so nothing recorded so far is lost and the web app / coach tools can still read iPhone exports.

**Decision: what happens to the cloud?** Three options, in order of recommendation.

| Option | What it gives | Cost / risk |
|---|---|---|
| **A. No sync at launch** (recommended for v1) | Fastest path to the store. Export/import files, AirDrop, Files app. One‑time import of existing Supabase rounds. | Coach (Capri Studio) gets data by export instead of live. |
| **B. iCloud sync via CloudKit** (recommended for v2) | Rounds follow the shooter across iPhone, iPad, Watch. No server, no login screen, free, private by design. SwiftData can mirror to CloudKit with little code if models are CloudKit‑safe. | Apple‑only (fine for a 100% Apple app). Coach still needs an export or a share link. |
| **C. Keep Supabase as an opt‑in "Share with coach"** | Preserves today's coach/admin web dashboard. | Keeps server, auth, privacy labels, RLS to maintain. Only worth it if the Admin workflow is essential. |

Decision taken: **A. Local storage only at launch.** B and C stay listed as later options, never as a login wall.

---

## 4. Target architecture

One Xcode workspace, one app target, local Swift packages. Pure logic is separated from UIKit/AVFoundation so it can be unit‑tested quickly (on a Mac, or on Linux with the open‑source Swift toolchain).

```
TrapShooterPro.xcworkspace
├── TrapShooterPro (app, SwiftUI)
│   ├── App/          TrapShooterProApp, TabView root, environment wiring
│   ├── Record/       RangeDataView, ConditionsView, TargetEntryView, ScorecardView, LedgerView
│   ├── Timer/        TimerView, InputPickerView, LevelMeter, RejectLog, TimerSettingsView, BreakDistanceView, TimeRecordingView
│   ├── Rounds/       RoundsListView, RoundDetailView
│   ├── Analysis/     OverviewTiles, TrendView, DimensionTables, TrapAnalysisView, FindingsView
│   ├── Schemes/      SchemeTableView
│   └── Settings/     ProfileView, DataView (export, import, backup), AboutView
├── Packages/
│   ├── TrapCore      (pure Swift) Round, Target, Scheme, Result, Direction, station math, direction quota,
│   │                 scoring, Schemes table, Analysis (8 dims, geometry fit, findings), BreakDistance ballistics,
│   │                 CSV writer, RoundDocument v2 codec (import/export JSON)
│   ├── ShotTimer     (AVFoundation) AudioDetector (unchanged), MicEngine (today's MicBridge minus JS),
│   │                 RoundRecorder (unchanged), FileAnalyzer (feeds an audio file through AudioDetector)
│   ├── TrapData      (SwiftData) models, container, migrations, v7 importer
│   ├── TrapReports   Scorecard (SwiftUI ImageRenderer → PNG), PDF (UIGraphicsPDFRenderer), ShareLink items
│   └── TrapWeather   CoreLocation one‑shot + Open‑Meteo client (async/await)
└── Tests/
    ├── TrapCoreTests        golden tests: JS output vs Swift output on the same fixture rounds
    └── ShotTimerTests       detector regression: fixture .m4a files + expected call/shot times
```

**Key technical choices**

- **iOS 17 minimum** (decided). SwiftData, `@Observable`, `ShareLink`, `ImageRenderer`. Universal app: iPhone and iPad, with `NavigationSplitView` on iPad.
- **State**: `@Observable` view models, `@Query` for lists. One `TimerSession` object replaces `MicBridge` + `window.__trapMic`: same messages (started, inputs, route, restarted, error, first, target, reject, level, diag, saved) become published properties and an `AsyncStream` of events.
- **Detector untouched.** `AudioDetector.swift` moves into the `ShotTimer` package as is. Its callbacks already land on the main queue, which is exactly what SwiftUI wants. A regression harness guards it.
- **"Time a recording"** is rebuilt by reading the file with `AVAudioFile` and pushing buffers into the same `AudioDetector` (a small `process(buffer)` entry point). That deletes the JavaScript duplicate for good.
- **Scorecard and PDF**: draw the scorecard once as a SwiftUI view; `ImageRenderer` gives the PNG, `UIGraphicsPDFRenderer` gives a real A4 PDF with vector text. The hand‑rolled JPEG‑in‑PDF goes away.
- **Fonts**: San Francisco (decided). The scorecard moves from Barlow / IBM Plex Mono to SF Pro and SF Mono.
- **Storage layout**: SwiftData store in Application Support; recordings stay in `Documents/Recordings` so the Files app still shows them.
- **Privacy**: mic and location usage strings stay; no tracking, no third‑party SDKs, so App Privacy labels are nearly empty ("Data not collected" if there is no sync).

**Data model (SwiftData)**

- `Round`: id, createdAt, updatedAt, date, startTime, startStation, session, sessionId, type, scheme, field, sky, wind, tempC, humidity, place, notes, weapon, ammo, choke1, choke2, appVersion, `targets: [Target]`.
- `Target`: seq 0–24, direction (L/S/R/none), result (G/Y/R/none), t1Ms, t2Ms, callDb, timerMic, noTargetCount. Station, trap, angle, height and break distance are **derived** from scheme + start station, not stored.
- `ShooterProfile`: name, dob, weapon, ammo, choke1, choke2. No email, no password.
- `TimerSettings` and `BreakDistanceSettings`: stored with `@AppStorage`‑style keys or a single settings model.
- Export/import uses the existing document v2 JSON shape, so the one‑time Supabase importer is a mapping, not a redesign.

---

## 5. Plan

Each phase ends with something installable on the phone. Estimates assume one developer writing the code and you building/testing on the Mac and at the range.

### Phase 0 — Foundations (about 1 week)

1. Join the **Apple Developer Program** (needed for TestFlight, App Store, CloudKit later).
2. Put the project in a **git repository** (GitHub). Zips stop here: code gets pushed, you pull on the Mac and press Run.
3. **Compile 7.0.7 as it is** in Xcode. Fix any red errors. This gives a known‑good baseline and verifies the detector on your device.
4. Build the **detector regression set**: turn the 9 range videos and the 18 Oct mic test into short `.m4a` fixtures with the expected call and shot times. This set is run after every change that touches audio.
5. Decisions in section 6: done.

### Phase 1 — Core logic and the shooting flow, native (about 3 weeks)

1. **TrapCore**: port schemes, station math, direction quota/odds, scoring, round document codec, break‑distance ballistics, CSV and analysis. Golden tests run the JavaScript functions on fixture rounds and assert the Swift results match to the last decimal. *Status: written (`Packages/TrapCore`, 9 source files, 3 test files, 5 fixture files). First `swift test` run happens on the Mac.*
2. **ShotTimer**: move `AudioDetector` and `RoundRecorder` unchanged; turn `MicBridge` into `TimerSession` (`@Observable`). Add `FileAnalyzer`. *Status: package written (detector and recorder byte‑identical, `TimerSession`, typed events); `FileAnalyzer` pending.*
3. **TrapData**: SwiftData models, container, autosave on every target entry (today's 500 ms debounce becomes a simple context save). *Status: written (`RoundRepository`, in‑memory + SwiftData, `Backup`, `Importer` for 7.x shapes) with tests.*
4. **Timer tab** in SwiftUI: start/stop, input picker, audio‑in line, live meter, rejects, settings, break distance, round audio + share.
5. **Record tab** in SwiftUI: range data, conditions (+ weather), target entry with the exact range flow (call + shots → direction + result → arm next target), Skip, Re‑time, Undo, NO TARGET, scorecard, ledger, done card.
6. Install on the phone, run a real round. At this point the WebView is no longer used for shooting.

### Phase 2 — The rest of the app and the clean break (about 2 weeks)

1. Rounds list and detail, delete with undo.
2. Analysis tab: tiles, trend, 8 dimensions, trap analysis with geometry fit and findings.
3. Schemes tab.
4. Settings: profile, timer defaults, data (export CSV / PNG / PDF via `ShareLink`, full‑library backup JSON, import backup).
5. **One‑time importer**: "Import my rounds from TRAP SHOOTER PRO" signs in once with the existing account over plain HTTPS to the Supabase REST endpoint, pulls `rounds.doc`, stores locally, and forgets the credentials. No Supabase SDK in the app.
6. Delete `ContentView` WebView, the `Web/` folder, `supabase.js`, `config.js`. Remove the Admin tab from the iOS app (it stays a web tool for Capri Studio).

### Phase 3 — App Store readiness (about 2 weeks)

1. **Quality**: Dynamic Type, VoiceOver labels on the entry buttons, dark mode (drop the forced light style), landscape or at least iPad decision, haptics on target entry, keep‑screen‑awake only while timing.
2. **Range testing**: TestFlight external beta with your test shooters (Yugan, Khalid, Pittu). Run the regression set on the final build.
3. **Store assets**: name check ("Shooter Pro" / "Trap Shooter Pro" availability and trademark), icon set, screenshots (6.9" and 6.5"), description, keywords, category Sports, age rating, privacy policy page (short, since nothing leaves the device), App Privacy answers, support URL.
4. **Review notes**: explain the microphone use (times the athlete's call and shots in Olympic Trap), that no account is needed, and that external receivers (DJI Mic Mini 2) are supported. Olympic/ISSF sport shooting is an accepted category; the notes should say so plainly.
5. Submit.

### Phase 4 — After launch (optional, in order of value)

1. **iCloud sync** (CloudKit through SwiftData) so rounds follow the shooter across devices.
2. **Coach sharing**: a share‑pack export (JSON + CSV + PDF) or an opt‑in "publish to coach" that posts a round to the existing Supabase table under a coach‑issued key.
3. **Apple Watch** companion for status and result entry (the bridge already reserved a "status" message for it).
4. **Live Activity** on the Lock Screen while the timer runs; **Siri Shortcut** "Start shot timer".
5. Localization (the sport is international).

---

## 6. Decisions (agreed 22 Oct 2026)

| Question | Decision |
|---|---|
| Minimum iOS | **iOS 17.0 and newer**, built against the latest SDK |
| Sync at launch | **None. Local storage only.** No account, no server, no network dependency. Cloud sync is not part of v1. |
| Name and identity | Project and App Store name **TrapShooterPro**, name under the icon **TrapShoot** (fits without truncation), bundle identifier `com.mtajudeen.trapshooterpro` unchanged |
| Devices | **iPhone and iPad** (universal) |
| Scorecard fonts | **San Francisco** (SF Pro, SF Mono). No bundled fonts. |
| Visual design | **Black‑and‑white system** from the supplied `bw-theme.css` / `login.css`, translated to iOS in `docs/design-system.md` and `Packages/TrapDesign` (light + dark, SF typography, 44 pt targets). |
| Source control | GitHub under **JIAMETRIC**. Code is pushed from the cloud session and pulled on the Mac. |

Consequences already applied to the baseline project: deployment target 17.0, device family iPhone + iPad, iPad orientations added, display name "TrapShoot" under the icon, build number 8, and the two user‑facing "Shooter Pro" strings in the Swift sources.

Note on the display name: iOS truncates names under the home‑screen icon at about 11 to 12 characters, so the icon label is **TrapShoot** (agreed 22 Oct 2026). The App Store listing keeps the full name TrapShooterPro.

Note on sync: with no sync, a user's rounds live only on that device. The **Data** screen therefore gets a one‑tap full backup (JSON) and restore, and the app participates in normal iPhone/iCloud device backups, so a phone upgrade carries the rounds over.

---

## 7. Risks and how the plan handles them

| Risk | Mitigation |
|---|---|
| Detector regresses during the move | `AudioDetector.swift` is moved byte‑for‑byte; fixture‑based regression tests run on every audio change |
| Ported maths differ from the web app (scores, angles, break distance, analysis) | Golden tests: JavaScript and Swift run on the same fixture rounds and must agree |
| Existing rounds lost | One‑time importer from Supabase + document v2 stays the export format |
| Code written without Xcode does not compile | Pure‑Swift packages can be compiled and tested with the Linux Swift toolchain in cloud sessions; UI code is built on your Mac via git pull, with small frequent commits |
| App Review rejects for account or web‑wrapper reasons | Both causes are removed by design: no login, no WebView |
| Range conditions (external receiver, poor signal) | All existing receiver handling is kept; the app no longer depends on the network at all |

---

## 8. Summary

Today: a well‑engineered native shot timer wrapped around a web app that needs an account and a server.
Target: the same timer, the same data, the same analysis, rebuilt as a SwiftUI app that works entirely on the phone, exports anything you need, and is ready for App Review. About 8 weeks of focused work in four phases, with the detector untouched and the existing data carried over.
