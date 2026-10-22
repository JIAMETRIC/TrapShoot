# Error handling and debugging

## Errors

1. Anything a screen can show conforms to `UserFacingError` (TrapCore): one plain sentence, an optional recovery
   sentence. Views render `DisplayError(any:)`; they never show a system `localizedDescription`.
2. Expected conditions are not errors: no weather, no location, a denied microphone, a disconnected receiver are
   **states** with a line of text on the screen, not alerts.
3. Imports and restores **sanitise, then report**: the round is saved with what can be fixed; `ImportReport.issues`
   lists what the shooter should look at. Nothing is thrown away silently.
4. The audio pipeline recovers by itself (restart after a hardware change, watchdog with three retries) and only then
   speaks, in plain words, with the thing to try.
5. `assertionFailure` for programmer errors in Debug; never `fatalError` in code that runs on the range.

## Logging

- `TrapLog.<category>` (`os.Logger`): app, timer, audio, data, network, ui. Levels: `debug` noisy details,
  `info` state changes, `notice` things a support mail needs, `error` failures handled, `fault` should never happen.
- Round data is `privacy: .private`. Counts, states, durations and error codes are public.
- Signposts for intervals the budgets mention (`docs/performance.md`).

## On the range: the support bundle

Settings → About → **Send diagnostics** builds `SupportBundle.make(...)`: app and device facts, storage report, audio
check line, recent log lines, MetricKit payloads if any. It is a text file the shooter mails. It replaces "send a
screenshot of the Timer tab".

## Debug screen (Debug and TestFlight builds)

Tap the version line five times in About:

- audio: input, type, sample rate, channels, buffers flowing, restarts, last ten events
- data: store size, recordings, last save duration, validation issues on the current round
- network and power: path, constrained, expensive, battery, low power, thermal
- actions: export logs, run the detector on a bundled sample, clear recordings, reset settings

## Debugging checklist

| Symptom | First look |
|---|---|
| No times appear | Timer tab audio line: input and "flowing"; `audio` log; receiver paired and unmuted |
| Times read long by ~50 ms | call onset trace back (detector v3.1 rule); compare against the recording with "Time a recording" |
| Round lost after a call | lifecycle: `appWillResignActive` saved it; check `data` log for the save before the interruption |
| Crash on open after update | schema migration; `TrapMigrationPlan` stages; MetricKit diagnostics file |
| Weather never fills | `network` log; `NetworkMonitor.isConstrained` (Low Data Mode); location authorization |
