---
name: simplify
description: Review recently changed code for clarity, reuse and efficiency, then apply the simplifications without changing behaviour. Quality only, not bug hunting.
---

# Simplify (adapted)

Adapted from the `code-simplifier` agent in anthropics/claude-plugins-official (Apache 2.0, see
`.claude/skills-extra/alternatives/code-simplifier/LICENSE`). The wording is shortened and not the original.

1. Look only at the code changed in this session, unless the user names a wider scope.
2. Remove duplicated logic, needless nesting, and abstractions used only once.
3. Prefer explicit code. Do not add nested ternaries or dense one-liners.
4. Keep every behaviour, output and public API the same. Run the tests after each change.
5. Report the changes that matter, with the file names.
