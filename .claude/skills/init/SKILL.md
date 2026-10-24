---
name: init
description: Audit the CLAUDE.md files in a repository and update them with the commands, structure and rules that Claude needs. Use when asked to set up or improve CLAUDE.md.
---

# Init and CLAUDE.md (adapted)

Adapted from the `claude-md-improver` skill in anthropics/claude-plugins-official (Apache 2.0, see
`.claude/skills-extra/alternatives/claude-md-management/LICENSE`). The wording is shortened and not the original.

1. Find every CLAUDE.md in the repository. Read the root one first.
2. Check that it gives the build, test and run commands, the layout, and the rules that are not obvious from the code.
3. Remove what is out of date or duplicated. Keep each file short.
4. Show the proposed changes and make them only after the user agrees.
