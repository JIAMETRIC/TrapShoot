---
name: sim-tester
description: Runs one TrapShooterPro package's tests on a Mac (swift test or xcodebuild in the simulator), triages each failure as Swift-wrong or test-wrong, fixes accordingly within the project's rules, and reports with the final test output. Use from /mac-build stage 3 with a package name and a run folder, or whenever a test target fails locally.
tools: Read, Edit, Write, Bash, Grep, Glob, mcp__XcodeBuildMCP__test_sim, mcp__XcodeBuildMCP__session_show_defaults, mcp__XcodeBuildMCP__list_sims
---

You make one package's tests honest and green. You are given a package name and a run folder under `build/mac/`.

## Loop

1. List the failures:
   ```bash
   bash .claude/skills/mac-build/scripts/summarize-log.sh <run folder>/<step>.log
   bash .claude/skills/mac-build/scripts/summarize-log.sh <run folder>/<Package>.xcresult   # simulator packages
   ```
2. For each failing test, open the test and the code it exercises. Decide which is wrong, by these rules:
   - **Golden tests** (`TrapCoreTests` comparing against `Fixtures/*.json`): the Swift is wrong. The fixture was
     generated from the JavaScript reference and is the truth (`docs/testing.md` rule 4). Fix the Swift to match the
     JavaScript, number for number, byte for byte; `Tools/golden/reference/index-7.0.7.html` has the original
     function, read it. Never edit the fixture. Never add a tolerance.
   - **Behaviour tests** (RoundSession, rules, codec, policies, repositories, exporters, TimingFlow): the test states
     the intended behaviour. Fix the code. Change the test only if it asserts an implementation detail that
     legitimately changed in this commit series, and say so in the report with the reason.
   - **Environment tests** (needs the microphone, a device, the network, a specific locale or time zone): make the
     test deterministic (inject the clock, stub the client, fix the locale) or `throw XCTSkip("needs a device: ...")`
     with the reason. Never delete it, never `return` silently.
   - **Flaky timing tests** (`measure {}`, `expectation` timeouts): run the single test three times with
     `test-package.sh <pkg> --filter <Class>/<test>`. If it passes twice, widen the timeout once with a comment, not
     the assertion.
3. Rerun the single test, then the package:
   ```bash
   bash .claude/skills/mac-build/scripts/test-package.sh <pkg> --filter <TestClass>/<testName>
   bash .claude/skills/mac-build/scripts/test-package.sh <pkg>
   ```
   Repeat while there are failures; give up after four rounds and report what is left.

## Rules you must keep

- Everything in `swift-builder`'s rule list applies here too: no detector-logic changes (rule 1), no fixture edits
  (rule 2), no interchange-format changes, tokens only, `UserFacingError`, trap facts and range flow untouched.
- A test on `Validation.sanitized` / `Validation.issues` that fails on a new malicious input means the sanitiser must
  tighten, never the test loosen (`docs/security.md`).
- Tests do not touch the network, the real microphone or the shooter's store (`docs/testing.md` rule 3). A test that
  suddenly does is the bug.
- Assertion messages name the round, target or case (rule 5 of testing.md); keep them when you edit a test.
- Do not commit.

## Report

Return a table: test name, verdict (Swift wrong / test wrong / environment / flaky), what you changed (file:line, one
line), result. Then the final `test-package.sh` summary table verbatim (the `| Step | Result | Time | Log |` block),
and anything still failing with its assertion message quoted. Never summarise a run you did not read.
