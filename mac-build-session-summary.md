# Mac build orchestration: session summary

*24 to 26 October 2026. Written on Windows for the MacBook session.*

## Outcome

- Everything in the phase plan that can be done without a Mac or the iPhone is on `main` (merge commit `ec90d00`, PR #1, now merged).
- The Mac work is organised as skills and agents that a Claude Code session on the MacBook can run in order.
- CI on the PR's final commit (`87bcbc3`) passed: golden fixtures, `swift test` for TrapCore, TrapData and TrapWeather, and the iOS job (app build, simulator package tests, UI test). The iOS job took 19 minutes.
- Nothing has been compiled or run on a Mac or an iPhone yet. Those checks are the MacBook session's job.

## What was built

**Skills** (`.claude/skills/`)

| Skill | Purpose |
|---|---|
| `mac-build` | Eight stages: preflight, the CI pipeline run locally, compile fixes, test triage, demo run with screenshots, MCP smoke test, design preview, session record |
| `mac-device` | 18-row iPhone and DJI Mic Mini 2 checklist, with the progress line each row closes |
| `mac-release` | Archive, TestFlight upload and tag; asks before every upload |
| `detector-fixtures` | Turns the owner's range recordings into regression fixtures |
| `operate` | Phase 9: weekly triage, iOS beta runs, quarterly security review |

`mac-build` also has a reference file, `phase-map.md`, which lists every open row of `docs/progress.md` with the skill, stage or agent that closes it.

**Agents** (`.claude/agents/`): `mac-preflight`, `swift-builder`, `sim-tester`, `app-verifier`, `design-reviewer`, `progress-scribe`, `support-triage`.

**Scripts** (`.claude/skills/mac-build/scripts/`): `preflight.sh`, `build-all.sh` (mirrors CI), `test-package.sh`, `run-demo.sh`, `summarize-log.sh`, and `lib.sh`. They write logs to `build/mac/<timestamp>/`.

**Code added to the app and tests**

- `FileAnalyzer` and `DetectorFixture`: feed a recording through the live detector and compare with expected times. `DetectorRegressionTests` skips until recordings exist; a synthetic test always runs.
- The only change to `AudioDetector.swift`: `setup` and `process` went from private to internal. No detection logic changed.
- Accessibility identifiers on the Record and Timer controls, a scripted demo timer (`-uitest`), and the `TrapShooterProUITests` target, added to the project, the scheme and CI.

## Decisions to know about

- Claude cannot edit `.claude/settings.json` in auto mode, so the owner pasted the allow-list by hand. It is committed as `ec8a8cb`.
- The Mac scripts must run on the MacBook's bash 3.2. They guard empty arrays for that reason.
- The `iOS` CI job is the first real compile of the hand-edited project file and the UI test target.

## Issues fixed during CI

1. `FileAnalyzer` used `MainActor.assumeIsolated` inside a plain callback, which did not compile. It now uses a locked sink.
2. The synthetic WAV was written with a format that `AVAudioFile` refused.
3. The Timer UI test could not find the Start button after tapping the tab. It now relaunches onto the Timer screen.
4. The file reader requested frames past the end of the file. It now reads only what remains.

## Still open

**Windows side**

- The local checkout is on branch `pages-and-skills`, with three commits for the GitHub Pages work and an untracked `hero_TrapShooterPro.html`. Keep or discard that work, then run `git switch main`.

**MacBook side**

1. One-time setup from `docs/mac-setup.md`: Xcode 26.3 or newer, `xcode-select`, Node, Claude Code, and "Allow external agents to use Xcode tools".
2. `git pull`, then open `TrapShooterPro.xcodeproj` in Xcode.
3. Run `claude` and type `/mac-build`. Preflight reports anything missing and the command to fix it.
4. Then `/mac-device` with the DJI receiver, `/detector-fixtures` for any recordings already on hand, and `/mac-release` once the Apple Developer account is active.

**Not covered by any skill**

- Recording the detector's regression set at the range, and a full round on a real range. These need the owner.
- Phase 9 operation over months, which begins after the first TestFlight build.

## Risks

- The iOS job passed on Apple's runners, but the simulator UI test has run only in CI. It may behave differently on the MacBook's Xcode version.
- The screenshots and design preview have not been reviewed by eye.
- The detector has not been checked against real recordings. Until the regression set runs, the timer's accuracy is unverified.
