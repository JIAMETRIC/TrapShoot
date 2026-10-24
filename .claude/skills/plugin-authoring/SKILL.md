---
name: plugin-authoring
description: Create or change a Claude Code plugin, its skills, commands, agents or hooks. Use when asked to build a plugin or a mod for Claude's interface.
---

# Plugin authoring (our version)

This is our own version, not the built-in file. The reference material is in
`.claude/skills-extra/alternatives/plugin-dev/` (Apache 2.0, from anthropics/claude-plugins-official).

1. Decide what the plugin must do, and which parts it needs: skills, commands, agents or hooks.
2. Use the plugin-dev reference for the file layout and each part's frontmatter.
3. Keep hooks small and say what they run. Do not add a hook without the user's agreement.
4. Test each part on its own before packaging the plugin.
