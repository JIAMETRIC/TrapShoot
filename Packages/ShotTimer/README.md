# ShotTimer

| File | Origin | Change |
|---|---|---|
| `AudioDetector.swift` | 7.0.7 app | none (byte for byte) |
| `RoundRecorder.swift` | 7.0.7 app | none (byte for byte) |
| `TimerTypes.swift` | new | public settings, inputs, route, events, `ShotTimerControlling` protocol |
| `TimerSession.swift` | port of `MicBridge.swift` | JavaScript calls became `TimerEvent`s and observable properties; share sheet became `recordingToShare()`; detector and recorder injected behind `ShotDetecting` / `RoundRecording` for tests; screen‑awake is the app's job (`ScreenAwake`) |

Not yet ported: "Time a recording" (file analysis). It needs the detector's `process` and `setup` to be callable from a
file reader; that is a two-word access change in `AudioDetector.swift`, done together with its regression fixtures.

## Reference receiver: DJI Mic Mini 2

The timer is tuned and tested with a DJI Mic Mini 2: transmitter on the shooter, receiver plugged into the iPhone.
The phone mic is the fallback. `AudioDetector` is not changed for it; everything is in `TimerTypes`/`TimerSession`:

| Where | What |
|---|---|
| `ReferenceReceiver.matches` | an external input whose port name contains "DJI" (any case) is the receiver |
| `ReferenceReceiver.inputID` | System default: the DJI receiver over any other external input; none present → `""`, the detector's own rule (first external, else phone mic). An input the shooter picked always wins |
| `AudioInput` / `AudioRoute.isReferenceReceiver` | for the Settings picker and the Timer tab |
| `AudioDiagnostics.line` | the 7.0.7 audio check line, with the receiver named: `Audio in: DJI Mic Mini 2 receiver (USBAudio) · 48 kHz · 2 ch, using ch 1 · receiving` |

Already in the detector and kept as is: a receiver can deliver 2 channels with only one transmitter live, so the
louder channel is followed; a fresh engine after any hardware change; a watchdog restart after 1.5 s without audio
(up to 3 times).

To confirm on a device (Phase 4): the port name and port type iOS reports for the receiver (the match assumes "DJI"
appears in the name), plug in before Start, plug in and unplug during timing, transmitter off and on.

Verify on a device, never only in the simulator: the simulator has no DJI receiver, route changes or real latency.

`RoundRecorder.folder` is `Documents/Recordings`; `TrapCore.AppConstants.recordingsFolder` carries the same name for the platform package.

Tests (`ShotTimerTests`, simulator, run in CI): settings mapping, event flow through fake detector callbacks, share
guard, DJI recognition, System default preference, audio check line.
