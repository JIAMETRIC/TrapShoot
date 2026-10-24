---
name: security-review
description: Review the pending changes on the current branch for security problems, and report each finding with its file and line. Use before merging security-sensitive changes.
---

# Security review (our version)

This is our own version, not the built-in file. It does not run the scanners or hooks from the
claude-security plugin in `.claude/skills-extra/alternatives/claude-security/`.

1. Read the diff of the current branch against its base.
2. Check for: secrets in code, unsafe input from files or the network, unsafe file paths, unvalidated data crossing a boundary, and weak crypto.
3. For each finding, give the file, the line, the risk, and a suggested fix.
4. Say clearly when nothing was found, and what was not checked.
