---
name: loop
description: Run a prompt again on an interval, defaulting to 10 minutes, or let the pace be chosen. Use when the user asks to repeat a task or check something regularly.
---

# Loop (our version)

This is our own version of the built-in skill of the same name. It is not the app's file.

1. Confirm the prompt and the interval with the user. The default is 10 minutes.
2. Run the prompt at each interval and report only what changed.
3. Stop when the user says so, or when the goal is reached.
4. Do not poll background work. Wait for it to report back.
