---
name: artifact-capabilities
description: Runtime features an artifact page can use, such as shared state, a question back to Claude or a file for the viewer. Load it before using any of them.
---

# Artifact capabilities (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Decide whether the page needs state that others see. If it does, use a shared capability.
2. Use browser storage only for small per-viewer conveniences, such as a collapsed section.
3. Wrap every storage read and write in try and catch, and make the page work without them.
4. Declare each capability the page uses, and list what it needs in the description.
