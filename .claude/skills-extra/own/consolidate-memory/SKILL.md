---
name: consolidate-memory
description: Review the memory files. Merge duplicates, fix stale facts, delete wrong entries and prune the index. Use when asked to clean up or consolidate memory.
---

# Consolidate memory (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Read the index file and every memory file it points to.
2. Group memories that cover the same fact. Merge them into the older file and delete the duplicate.
3. Check each fact against the repository or the user. Fix or delete anything out of date.
4. Keep one line per memory in the index. Remove index lines whose file no longer exists.
5. Report what was merged, fixed and deleted.
