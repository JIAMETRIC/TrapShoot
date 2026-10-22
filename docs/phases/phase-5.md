# Phase 5 — Record and Timer screens `[OOP · CMS · TAB · SEF]` — built and tested in CI; range and device checks pending

The first native screens, the end of the WebView for shooting.

**Application layer (app target)**
- `RecordModel` (`@Observable`): owns a `RoundSession`, a `RoundRepository`, the `TimerSession`, the `BreakDistanceModel`;
  saves after every entry; maps `TimerEvent.target` to `recordTiming`; arms the next target after a result; ignores shots
  while a result is being entered (7.0.4 rule).
- `TimerLifecycle` adapter (`LifecycleParticipant`): save on resign, stop on background, refresh inputs on foreground.
- Scene storage: current round id and selected tab survive relaunch; kill‑and‑resume restores the round from the store.

**Screens (TrapDesign only)**
- Record: range data and conditions (weather fill via `TrapWeather`, auto once, manual button), the 25‑target entry
  (station and target, direction row, result row, full‑width NO TARGET, Skip, Re‑time, Undo, Previous/Next), scorecard
  strip, ledger table, done card, share panel.
- Timer: Start/Stop, input picker, audio check line, readout `0.000` in `BWFont.readout`, live level at 20 Hz (5 Hz when
  conserving), rejected sounds, timer settings, break distance settings, round audio toggle and share.
- Phone: `TabView`; iPad: `NavigationSplitView` with ink sidebar; `AdaptiveSplit` puts Timer beside Record at ≥ 600 pt.
- Keyboard: `BWKeys` on every control; VoiceOver labels; Dynamic Type to accessibility sizes; haptics on entry.

**Project**
- Add the local packages to `TrapShooterPro.xcodeproj` (package references and product dependencies), new `App/`
  sources, remove `ContentView.swift`/`MicBridge.swift`/`LocationFetcher.swift` from the target when the native root
  replaces the WebView.

**Exit gate:** a full 25‑target round recorded on a real range with timing; kill the app mid‑round and reopen: same
round, same target, same times; iPad split layout checked at 820 and 1180 pt windows and in Split View; UI test drives a
round through a scripted timer.
