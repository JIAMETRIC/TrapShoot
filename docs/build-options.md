# TrapShooterPro — How to compile, test and ship without a Mac on your desk

*22 October 2026*

## The constraint

- Xcode runs only on macOS. Compiling Swift for iOS, running the simulator, rendering SwiftUI previews, signing and uploading builds all need a Mac with Xcode.
- XcodeBuildMCP and Xcode 26.3's own MCP bridge are tools Claude uses **on that Mac**. They do not give a Windows PC or a Linux cloud container a compiler.
- The repository is already prepared for a Mac session: `CLAUDE.md`, `.mcp.json` (XcodeBuildMCP + Xcode bridge), `.claude/settings.json`, `docs/mac-setup.md`.

## What each machine can do

| Task | Windows PC (Claude Desktop) | Linux cloud session | Mac with Xcode |
|---|:-:|:-:|:-:|
| Edit code and docs, review, commit, push | yes | yes | yes |
| Regenerate golden fixtures with Node | yes | yes | yes |
| `swift test` for **TrapCore** (Foundation only) | yes, with the Swift toolchain for Windows | yes, once `download.swift.org` is allowed in the environment's network settings | yes |
| Compile TrapData, TrapWeather, ShotTimer, TrapDesign, TrapPlatform, TrapReports (Apple frameworks) | no | no | yes |
| Build and run the app, simulator, device, SwiftUI previews | no | no | yes |
| Archive, TestFlight, App Store submission | no | no | yes |

## The three ways to get a Mac

### 1. A physical Mac
Any Mac that runs the Xcode version supporting iOS 17 and the iPhone 17 Pro Max. Xcode 26 needs macOS Sequoia or newer: an Apple silicon Mac, or a 2019 or later Intel model. A Mac mini is the cheapest permanent setup. Needed anyway for Phase 4 (DJI receiver, route changes, timing on a real device) and convenient for the final App Store steps.

Setup: `docs/mac-setup.md` (Xcode, `xcode-select`, Node, Claude Code, enable *Allow external agents to use Xcode tools*).

### 2. A rented Mac in the cloud
MacStadium, MacinCloud or similar, reached from the Windows PC by remote desktop. Claude Code and Xcode run there with the same repository setup. A connected iPhone is not available, so device testing happens through TestFlight builds installed over the air.

### 3. GitHub Actions macOS runners (recommended daily loop)
Already in the repository:

- `.github/workflows/ci.yml` runs on every push and pull request: fixtures match the JavaScript, `swift test` for TrapCore, TrapData and TrapWeather on macOS, the app and iOS‑only packages built and tested in the simulator.
- `.github/workflows/release.yml` (manual) archives and uploads to TestFlight with an App Store Connect API key.

Steps:
1. Connect GitHub at https://claude.ai/connect-github, install the Claude GitHub App on the JIAMETRIC account, create the repository, push the commits (the zip holds the full history).
2. Every push is then compiled on a hosted Mac; compile errors and test results come back as logs that Claude reads and fixes from any machine.
3. Join the Apple Developer Program, create an App Store Connect API key, add the secrets named in `release.yml`, run the workflow, install the TestFlight build on the iPhone.

The loop is slower than a local Mac but turns "nothing compiled yet" into "compiled on every commit".

## Partial option available right now: Swift toolchain in the cloud session
The cloud session could not reach `download.swift.org` (network policy denied the host). Allowing that host under *Allowed domains* in the environment settings, with the package managers box left ticked, lets Claude install the Linux toolchain and run `swift test` for TrapCore: about 1,400 source lines, 540 test lines and all golden fixtures. Apple‑framework packages still need a Mac. Linux Foundation differs from Apple's in a few corners, so a Linux pass is strong evidence, not proof.

## Recommendation
1. Connect GitHub now; let CI compile everything on Apple's hosted runners on every push.
2. Use GitHub Actions as the daily build loop; fix what the logs show.
3. Optionally allow `download.swift.org` so the cloud session can test TrapCore itself.
4. Get access to a physical Mac for Phase 4 device verification (DJI receiver, 1 hour timing, battery) and for the final App Store submission.
