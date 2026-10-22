## What

One or two sentences: what changes for the shooter, or what changes for the code.

## Why

The reason, or the issue it closes.

## Checks

- [ ] `swift test` green for TrapCore, TrapData, TrapWeather (or: not touched)
- [ ] Golden fixtures unchanged, or regenerated on purpose because the JavaScript reference changed
- [ ] `AudioDetector.swift` untouched, or the detector regression set was run and the results are in the description
- [ ] Light and dark mode checked; Dynamic Type at the largest regular size
- [ ] Privacy strings, privacy manifest and `docs/` updated where behaviour changed
- [ ] Tried on a real iPhone when audio, receivers or timing are involved
