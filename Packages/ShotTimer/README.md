# ShotTimer

| File | Origin | Change |
|---|---|---|
| `AudioDetector.swift` | 7.0.7 app | none (byte for byte) |
| `RoundRecorder.swift` | 7.0.7 app | none (byte for byte) |
| `TimerTypes.swift` | new | public settings, inputs, route, events, `ShotTimerControlling` protocol |
| `TimerSession.swift` | port of `MicBridge.swift` | JavaScript calls became `TimerEvent`s and observable properties; share sheet became `recordingToShare()`; detector and recorder injected behind `ShotDetecting` / `RoundRecording` for tests; screen‑awake is the app's job (`ScreenAwake`) |

Not yet ported: "Time a recording" (file analysis). It needs the detector's `process` and `setup` to be callable from a
file reader; that is a two-word access change in `AudioDetector.swift`, done together with its regression fixtures.

Verify on a device, never only in the simulator: the simulator has no DJI receiver, route changes or real latency.

`RoundRecorder.folder` is `Documents/Recordings`; `TrapCore.AppConstants.recordingsFolder` carries the same name for the platform package.

Tests (`ShotTimerTests`, simulator): settings mapping, event flow through fake detector callbacks, share guard.
