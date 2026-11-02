# TrapShooterPro: start here on the MacBook

*Written 2 November 2026 on Windows, for the first session on the MacBook. Combines the project handoff with the
MacBook's Xcode setup notes.*

Start here on the Mac. The full brief Claude follows is `MAC-AUTONOMOUS-RUN.md`. General setup is in
`docs/mac-setup.md`. **Where this file and those differ on the Xcode path, this file is right for this MacBook.**

## Where the project stands

- The app is 100 % Swift. It is 8 local packages (TrapCore, TrapDesign, TrapData, TrapWeather, TrapPlatform, ShotTimer,
  TrapReports, TrapApp) plus the app target and a UI test target.
- `main` is green in GitHub Actions. That covers the golden fixtures, `swift test`, the simulator app build, the package
  tests and the UI test. On 1 November the golden fixtures were regenerated from the 7.0.7 reference and matched the
  committed ones byte for byte.
- **Nothing has been built on a Mac or run on an iPhone yet.** That is what this machine is for.
- The timer's accuracy has not been checked against real range recordings yet.
- CI builds with **Xcode 16.4**. This Mac has **Xcode 27.2**, whose newer compiler may warn or fail where CI did not.
  The first run's fix loops (step 4) handle that; anything left over goes under **Open** in the session record.

## 1. This MacBook

| Item | Value |
|---|---|
| macOS | 26.6.2, Apple Silicon (arm64) |
| Xcode | 27.2 (build 27B52, released 29 October 2026), Apple signed, accepted by Gatekeeper |
| Xcode location | `/Users/MEYYARIVAN/Desktop/MEYYARIVAN/Applications/Xcode.app` (**not** `/Applications`) |
| How installed | Apple's `Xcode_27.2.xip` from developer.apple.com, checked with `pkgutil --check-signature`, expanded with `xip --expand`, verified with `spctl -a -vv`; the `.xip` files went to the Trash |

Because Xcode is not in `/Applications`, every `sudo xcode-select -s /Applications/Xcode.app` line in the other docs
and in the preflight hints must use the path above instead. The preflight script itself accepts any `Xcode.app`
location.

To update Xcode later, download the newer `.xip` and repeat the install steps. Keep or remove the old `Xcode.app`.

## 2. One-time setup (each step needs your Mac password or a download)

Point the command line at this Xcode instead of `/Library/Developer/CommandLineTools`:

```bash
sudo xcode-select -s /Users/MEYYARIVAN/Desktop/MEYYARIVAN/Applications/Xcode.app/Contents/Developer
```

Accept the licence:

```bash
sudo xcodebuild -license accept
```

Install the components Xcode needs on first launch:

```bash
xcodebuild -runFirstLaunch
```

Install the iOS Simulator, which the `.xip` does not include (large download):

```bash
xcodebuild -downloadPlatform iOS
```

Install Node.js, which Claude's XcodeBuildMCP server runs on. Skip this if `node -v` already prints a version.
Without Homebrew, use the installer from nodejs.org.

```bash
brew install node
```

Check the setup:

```bash
xcode-select -p
```

```bash
xcodebuild -version
```

```bash
xcrun simctl list runtimes
```

```bash
xcrun --find mcpbridge
```

Expected: the first prints `.../Applications/Xcode.app/Contents/Developer`. The second prints `Xcode 27.2` /
`Build version 27B52`. The third lists an iOS runtime. The fourth prints a path.

In Xcode, turn on **Settings → Intelligence → Model Context Protocol → Allow external agents to use Xcode tools**.

Optional, needed only for TestFlight later: sign in under **Xcode → Settings → Accounts** with the Apple Developer
account.

If a pop-up offers to install the "Command Line Developer Tools", cancel it. Xcode already includes them.

## 3. Get the code

Clone a fresh copy. Do not copy the folder from the Windows PC, because its line endings break the bash scripts. The
repo is public, so no GitHub sign-in is needed to clone. Pushing later needs one.

```bash
git clone https://github.com/JIAMETRIC/TrapShooterPro.git
```

```bash
cd TrapShooterPro && open TrapShooterPro.xcodeproj
```

If the folder already exists, run `git pull` in it instead of cloning.

There is nothing else to install. The packages are local Swift packages referenced by the project, with no CocoaPods
and no third-party dependencies.

**Keep Xcode open with the project loaded** for the whole session. Claude's Xcode connection only works while it is
open.

## 4. Start Claude

Open the cloned `TrapShooterPro` folder in the Claude desktop app (Code tab) and start a new session. Paste:

> Read MAC-START-HERE.md and MAC-AUTONOMOUS-RUN.md, then carry out MAC-AUTONOMOUS-RUN.md. Xcode is at /Users/MEYYARIVAN/Desktop/MEYYARIVAN/Applications/Xcode.app, not /Applications. Stop only where it says to stop.

If Claude reports that **xcode** is not connected, check the Intelligence setting in step 2 and that the project is
open in Xcode. Everything except the design preview still runs without it.

## 5. What Claude does in that run (20–30 minutes the first time)

| Step | What happens | Result |
|---|---|---|
| A. Preflight | Checks Xcode, simulators, Node, MCP servers, git, disk | Any FAIL comes with the command that fixes it |
| B. Full pipeline | The CI pipeline, run locally: fixtures, every package, the app, the simulator tests | `build/mac/<timestamp>/summary.md` |
| B'. Fix loops | Compile errors and test failures fixed one package at a time | Local commits, one topic each |
| C. App runs | Demo mode in the simulator, every screen, light and dark, iPhone and iPad | Screenshots, checked against the design system |
| D. Smoke and design | UI snapshot, SwiftUI previews rendered light and dark | Closes "Design preview rendered light and dark" |
| E. Record | Session record and progress tracker updated from evidence | `docs/mac-sessions/<date>.md`, `docs/progress.md` |
| F. Phase check | Each phase 0–9 marked "verified on Mac", "needs device" or "needs you" | One line per phase in the record |

## 6. Where Claude stops and asks you

- Before any `git push`, pull request or merge. All commits stay local until you approve.
- Before any signing, archive, TestFlight or App Store upload.
- Before anything that needs the iPhone, the DJI Mic Mini 2 receiver or you in person.
- Before changing the shot detector (`AudioDetector.swift`), regenerating golden fixtures, or changing the JSON or CSV
  export formats.
- If a failure is still there after three fix rounds. It is listed under **Open**, not hidden.

At the end, Claude sends one message with these parts: **Passed on Mac**, **Fixed**, **Open**, **Needs you** and
**Next**.

## 7. After the first run

| Command | When | Needs |
|---|---|---|
| `/mac-build` | Rebuild and retest any time after changes | Mac |
| `/mac-device` | The 18-row checklist: DJI receiver recognised, plug and unplug, phone call, Low Power Mode, battery, backup and restore, VoiceOver… | iPhone, cable, DJI Mic Mini 2, you |
| `/detector-fixtures` | Turn range videos and mic tests into timer regression recordings | The recordings (ffmpeg) |
| `/mac-release` | Archive, TestFlight upload, tag `v8.0.0-b1`, App Store material | Apple Developer account, your go-ahead |

## 8. Quick fixes

| Symptom | Fix |
|---|---|
| Preflight says `xcode-select` points at the Command Line Tools | Run the `xcode-select` line in step 2 (the path in this file, not `/Applications`) |
| `cannot find "mcpbridge"` | Same `xcode-select` line; Xcode 26.3 or newer is needed, and 27.2 qualifies |
| No iPhone simulator | `xcodebuild -downloadPlatform iOS`, or Xcode → Settings → Components |
| XcodeBuildMCP times out on first use | `npx` is downloading it; retry |
| Xcode asks to allow an MCP connection | Allow it (it may ask a few times) |
| Script fails with `$'\r'` errors | The folder was copied from Windows; clone fresh from GitHub |

## Key files

`CLAUDE.md` (project rules) · `MAC-AUTONOMOUS-RUN.md` (the run brief) · `docs/progress.md` (what is done) ·
`docs/phases/README.md` (phase plan and gates) · `docs/mac-session.md` (runbook) · `docs/mac-setup.md` (setup)
