# Phase 1 — Foundation, tooling, design tokens `[CMS · SEF · TAB]` — done, verification on the Mac pending

| Deliverable | Status |
|---|---|
| Git repository with the 7.0.7 baseline as the first commit | ✅ |
| Project settings: iOS 17, iPhone + iPad, display name TrapShoot, build numbering | ✅ |
| Privacy manifest in the project | ✅ |
| CI: fixtures current, `swift test`, simulator build and tests; manual TestFlight workflow | ✅ (runs after the GitHub push) |
| Xcode MCP tooling for Claude sessions (`.mcp.json`, `docs/mac-setup.md`) | ✅ |
| `TrapDesign`: tokens (light/dark), SF typography, metrics, motion, components, breakpoints, keyboard shortcuts | ✅ |
| Golden fixture generator (`Tools/golden/generate.js`) | ✅ |

**Tasks left:** open the project on the Mac once, press Run on the phone (baseline), open `BWComponents.swift` in the
canvas, connect GitHub and push so CI runs.

**Exit gate:** fresh clone builds on the Mac in under 15 minutes; CI green on `main`; the design preview renders in light
and dark; `Breakpoint(width:)` returns phone / tabletSmall / tabletLarge at 390, 820 and 1180 pt.
