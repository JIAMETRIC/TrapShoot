---
name: fewer-permission-prompts
description: Find the read-only commands that were approved often in past sessions and propose an allowlist that reduces permission prompts. Show the change before writing it.
---

# Fewer permission prompts (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Read the past session logs and count the read-only commands that were approved.
2. Keep only commands that do not write, delete, send or install anything.
3. Propose the allowlist entries, most used first.
4. Show the proposed change, and write it only after the user agrees.
