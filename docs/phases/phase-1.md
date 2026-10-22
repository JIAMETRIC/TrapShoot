# Phase 1 — Foundation, tooling, design tokens `[CMS · SEF · TAB]` — done; CI green, design preview not yet rendered

| Deliverable | Status |
|---|---|
| Git repository with the 7.0.7 baseline as the first commit | ✅ |
| Project settings: iOS 17, iPhone + iPad, display name TrapShoot, build numbering | ✅ |
| Privacy manifest in the project | ✅ |
| CI: fixtures current, `swift test`, simulator build and tests; manual TestFlight workflow | ✅ green on `main` since 22 October 2026 |
| Xcode MCP tooling for Claude sessions (`.mcp.json`, `docs/mac-setup.md`) | ✅ |
| `TrapDesign`: tokens (light/dark), SF typography, metrics, motion, components, breakpoints, keyboard shortcuts | ✅ |
| Golden fixture generator (`Tools/golden/generate.js`) | ✅ |

**Tasks left:** open the project on the Mac once, press Run on the phone (baseline), open `BWComponents.swift` in the
canvas. Done: GitHub connected (`JIAMETRIC/TrapShooterPro`), CI green on `main`.

**Exit gate:** fresh clone builds on the Mac in under 15 minutes; CI green on `main`; the design preview renders in light
and dark; `Breakpoint(width:)` returns phone / tabletSmall / tabletLarge at 390, 820 and 1180 pt.
