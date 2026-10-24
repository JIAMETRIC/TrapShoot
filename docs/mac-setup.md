# Mac setup for building TrapShooterPro with Claude Code

## Once

1. Install **Xcode 26.3 or newer** from the App Store and open it once to finish installing components.
2. Point the command line at the full Xcode, not the Command Line Tools:
   ```sh
   sudo xcode-select -s /Applications/Xcode.app
   xcrun --find mcpbridge      # must print a path
   ```
3. Install **Node.js** (for `npx`): `brew install node`.
4. Install Claude Code if needed: `npm install -g @anthropic-ai/claude-code`.
5. In Xcode: **Settings → Intelligence → Model Context Protocol → Allow external agents to use Xcode tools** (on).
6. Join the Apple Developer Program and sign in under Xcode → Settings → Accounts.

## Every time

```sh
cd TrapShooterPro
git pull
open TrapShooterPro.xcodeproj      # Xcode must be running with the project open for the Xcode MCP bridge
claude
```

The repo's `.mcp.json` registers two servers and `.claude/settings.json` approves them, so no `claude mcp add` is needed.
Check with `/mcp` inside Claude Code: both **XcodeBuildMCP** and **xcode** should show as connected.

Then type `/mac-build`. It runs the readiness check, the whole CI pipeline locally, the fix loops, the demo run with
screenshots and the design preview, and leaves a record in `docs/mac-sessions/`. The full sequence and what each step
produces: `docs/mac-session.md`.

If you prefer registering them globally instead of per project:

```sh
claude mcp add --transport stdio XcodeBuildMCP -- npx -y xcodebuildmcp@latest mcp
claude mcp add --transport stdio xcode -- xcrun mcpbridge
```

## What each server is for

| Need | Use |
|---|---|
| Build, fix compile errors, run unit tests, boot simulator, install and launch, screenshots, logs | XcodeBuildMCP |
| Live diagnostics as you edit, builds and tests inside the open Xcode, **render a SwiftUI Preview** to an image | Xcode MCP bridge (`xcrun mcpbridge`) |
| Microphone, DJI receiver, timing accuracy | Real iPhone, Xcode Run; not the simulator |

Xcode may ask to allow the MCP connection the first few times; accept it.

## Claude agent inside Xcode (optional)

Xcode 26.3 can also host Claude as its coding agent (Settings → Intelligence → Anthropic). That agent reads its own MCP
config at `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` and runs with a limited PATH, so
`npx` should be wrapped in a login shell there, for example `"command": "/bin/zsh", "args": ["-lc", "npx -y xcodebuildmcp@latest mcp"]`.

## Troubleshooting

- `cannot find "mcpbridge"`: step 2 above.
- XcodeBuildMCP tool calls time out on first use: `npx` is downloading the package; retry.
- The design preview looks wrong: open `Packages/TrapDesign/Sources/TrapDesign/BWComponents.swift` and use the canvas,
  or ask Claude to `RenderPreview` it through the Xcode bridge.
