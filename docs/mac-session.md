# The Mac session, step by step

*Written 24 October 2026 on Windows, to be executed on the MacBook.* Setup of the machine itself is in
`docs/mac-setup.md`; this page is what to type once that is done, and what each step leaves behind.

## What is in the repository for it

| Piece | Path | Role |
|---|---|---|
| `/mac-build` | `.claude/skills/mac-build/SKILL.md` | the orchestration: eight stages, which agent handles which, exit criteria |
| its scripts | `.claude/skills/mac-build/scripts/` | `preflight.sh`, `build-all.sh` (CI locally), `test-package.sh` (one package), `run-demo.sh` (launch + screenshots), `summarize-log.sh`; all write to `build/mac/<timestamp>/` |
| its reference | `.claude/skills/mac-build/reference/stages.md` | durations, step names, dependency order, CI vs local differences |
| `/mac-device` | `.claude/skills/mac-device/SKILL.md` | the thirteen-row iPhone + DJI checklist, who does what, how results are recorded |
| `/mac-release` | `.claude/skills/mac-release/SKILL.md` | archive, TestFlight, tag, submission material; asks before every upload |
| agents | `.claude/agents/` | `mac-preflight`, `swift-builder`, `sim-tester`, `app-verifier`, `design-reviewer`, `progress-scribe` |
| MCP servers | `.mcp.json`, `.claude/settings.json` | XcodeBuildMCP (build, run, test, screenshots) and the Xcode bridge (previews, diagnostics) |
| records | `docs/mac-sessions/` | one file per session, written by `progress-scribe`; `docs/progress.md` rows flip from the evidence there |

## Day one on the MacBook

```sh
cd TrapShooterPro && git pull
open TrapShooterPro.xcodeproj        # for the Xcode bridge; XcodeBuildMCP works without it
claude
```

Inside Claude Code:

1. `/mcp` should list **XcodeBuildMCP** and **xcode** as connected. If `xcode` is not, previews (stage 6) are skipped;
   everything else still runs.
2. `/mac-build`. Claude runs preflight, then the whole CI pipeline locally in the background (20–30 minutes the first
   time, DerivedData cold), reads the summary, dispatches fixers only for what failed, launches the app in demo mode,
   takes the 24 screenshots, renders the design preview, and ends with a session record and `docs/progress.md`
   updated. You review the commits it proposes; you decide on the push.
3. Look at `docs/mac-sessions/<date>.md`. Anything under **Open** is the real state of the app on a Mac.

Expected outcome of the first session, if CI was telling the truth: every step passes, possibly a handful of
newer-SDK warnings fixed, the design preview verified, and the "Design preview rendered light and dark ⏳ Mac" row
turned ✅.

## Then, with the iPhone and the DJI receiver

`/mac-device`. Claude builds to the phone and walks you through the thirteen checks one at a time; you plug, unplug,
call, shoot (dry), and wait out the one-hour battery row. It reads the logs and records each row. The exact port name
of the DJI Mic Mini 2 receiver is the single most valuable fact from this session; it goes into the record and into a
comment beside `ReferenceReceiver`.

## Then, when the Apple Developer account is active

`/mac-release`. Claude checks that today's `/mac-build` passed on the current commit, shows you version and build
number, and archives and uploads only after you say yes. The first upload is tagged `v8.0.0-b1`.

## Where things land

```
build/mac/<timestamp>/        logs, .xcresult bundles, summary.md, shots/   (git-ignored, safe to delete)
build/mac/DerivedData/        Xcode's build cache for the scripts            (git-ignored)
docs/mac-sessions/<date>*.md  the record, with up to ten screenshots         (committed)
docs/progress.md              rows flipped only from evidence in a record    (committed)
```

## If something goes wrong

- Preflight FAIL lines name the command to run. Nothing else proceeds until they are OK.
- A step fails and the fixer gives up: the record says so under Open, with the compiler or assertion line. Bring it
  to a normal Claude session with that line; the fix is ordinary engineering.
- The simulator hangs: `xcrun simctl shutdown all`, rerun the step with `test-package.sh <pkg>`.
- A build passes only after deleting `build/mac/DerivedData`: a stale module cache, not a code problem. Note it.
- The orchestrator wants to touch `AudioDetector.swift`, the fixtures or the interchange formats: it is told to stop
  and ask. The answer is almost always no; those have their own procedures (CLAUDE.md rules 1 and 2).
