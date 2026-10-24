---
name: update-config
description: Change Claude Code settings in settings.json or settings.local.json, such as permissions, environment variables and hooks. Validate the JSON and ask before any security-related change.
---

# Update config (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Read the current file first. Keep every key you are not changing.
2. Make the smallest edit. Keep the JSON valid.
3. Ask before changing permissions, hooks or anything that runs commands.
4. Say which file changed and show the changed lines.
