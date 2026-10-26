---
name: code-review
description: Review a pull request for bugs and CLAUDE.md compliance, then report the findings on the pull request. Use when asked to review a PR.
---

# Code review (adapted)

Adapted from the `code-review` command in anthropics/claude-plugins-official (Apache 2.0, see
`.claude/skills-extra/alternatives/code-review/LICENSE`). The wording is shortened and not the original.

1. Skip the review if the PR is closed, a draft, trivial, automated, or already reviewed.
2. Find the CLAUDE.md files that apply: the root one and any in folders the PR changes.
3. Read the change and list the issues: CLAUDE.md breaches, obvious bugs, and problems against the history and comments of the changed code.
4. Keep only issues you can verify in the changed lines. Drop style nits, things a compiler or CI would catch, and pre-existing problems.
5. Post one short comment with `gh pr comment`. Link each issue to the file and line with the full commit SHA. If nothing is found, say so.
