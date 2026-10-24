---
name: artifact-design
description: Design rules for HTML pages published as artifacts. Colour tokens on :root, dark mode, a 16px side gutter at phone width and no horizontal scroll.
---

# Artifact design (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Put every colour, font size and radius in tokens on `:root`.
2. Redefine the colour tokens for dark mode with `prefers-color-scheme`.
3. Give `body` an explicit background.
4. Keep a 16px side gutter. Wrap wide tables in a box that scrolls on its own.
5. Check the page at phone width before publishing.
