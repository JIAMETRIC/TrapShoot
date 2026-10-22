# Phase 4 — Shot timer engine `[OOP · CMS · DSA]` — package written, device verification pending

`Packages/ShotTimer`: `AudioDetector.swift` and `RoundRecorder.swift` byte for byte; `TimerSession` replaces `MicBridge`.

**Tasks**
1. Record the regression set: the 9 range videos and the 18 Oct mic test as `.m4a` with expected call and shot times
   (`Tools/detector-fixtures/<name>.m4a` + `<name>.json`).
2. `FileAnalyzer`: feed a file through the detector (needs `process` and `setup` made internal in `AudioDetector.swift`;
   the only change ever made to that file, done with the regression set in place).
3. Detector regression test target that runs every fixture and asserts within 7 ms (1st shot) and 3 ms (call onset).
4. Device checks: phone mic, DJI Mic Mini 2 plugged in before Start, plugged in during timing, unplugged during timing,
   phone call during timing, Low Power Mode, 1 hour continuous timing.

**Exit gate:** every fixture within tolerance; the four receiver scenarios recover as in 7.0.4 (restart within 0.5 s,
watchdog note after three failed restarts); battery under 10 % per hour of timing; no allocation in the audio callback
(Instruments Allocations shows a flat line while timing).
