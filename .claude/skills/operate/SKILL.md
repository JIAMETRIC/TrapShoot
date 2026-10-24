---
name: operate
description: Phase 9 operation of TrapShooterPro after release, with no server: the weekly triage (App Store Connect crashes and reviews, shooters' support bundles with their MetricKit payloads, the service levels in docs/phases/phase-9.md), the per-iOS-beta run (detector regression set and UI test), the quarterly security review and the yearly minimum-iOS decision, plus evaluating the deferred options (iCloud sync, coach sharing, Watch, Live Activity, localisation). Use when asked to "triage", "read this support bundle", "check crash-free", "do the weekly review", "iOS beta is out", or anything about running the shipped app.
---

# Operate: Phase 9

There is no backend, so every signal arrives as a file or a page: a support bundle the shooter mails, a MetricKit
payload inside it, App Store Connect's crash and review pages, TestFlight feedback. The work is reading them against
fixed targets and turning findings into small, ordinary engineering tasks.

**Targets** (`docs/phases/phase-9.md`): crash-free sessions > 99.5 %, hangs < 1 per 100 sessions, cold launch p95
< 400 ms, timer accuracy within 7 ms on the regression set, support bundles answered within 2 days.

## Weekly triage (30 min)

1. **Support bundles.** For each new one, dispatch **support-triage** with the file path. It returns device, build,
   audio line, storage, the error lines from the log, and the MetricKit numbers if a payload is attached, plus a
   suggested reply and a suggested task. You send nothing; the reply is text for the owner to mail.
2. **App Store Connect.** The owner opens Crashes and Ratings; paste the text or screenshots. Group crashes by top
   frame; one task per group. A review that reports a defect becomes a task; a review that asks for a feature goes to
   the options list below, not to a task.
3. **Service levels.** Fill one line per metric in `docs/operations/<YYYY-MM-DD>.md` (create the folder on first use):
   measured value, source, within target yes/no. MetricKit's `MXAppLaunchMetric` and `MXAppResponsivenessMetric`
   histograms give launch and hang numbers; crash-free comes from App Store Connect or from the count of
   `diagnostics-*.json` payloads over sessions.
4. **Tasks.** Each finding is a normal task with the evidence path; nothing here changes code directly. A detector
   complaint ("it missed my shots") is never fixed by ear: ask for the round's recording (Settings → Data →
   recordings) and make it a fixture with `/detector-fixtures`.

## Per iOS beta or Xcode release (on the Mac, 1 h)

1. `/mac-build` on the new Xcode; fix what breaks (usually deprecations).
2. The regression set and the UI test are part of stage 1 (`sim-test-ShotTimer`, `ui-test`). Both must pass before
   the beta is called compatible.
3. `/mac-device` rows 1 to 5 on a phone running the beta, with the DJI receiver: the audio route behaviour is what
   iOS betas change most often.

## Quarterly

- Security review against `docs/security.md`: validation at the boundaries (`Validation.sanitized`, CSV formula
  safety, file-name stripping, backup import), the privacy manifest against the APIs used, no new network calls. It
  is a read of the code with that checklist; findings become tasks.
- Dependencies: there are none by design (CLAUDE.md rule 3). Confirm it is still true: `grep -r "import " Packages
  | grep -v -E "Foundation|SwiftUI|SwiftData|AVFoundation|UIKit|Observation|MetricKit|Network|CoreLocation|UserNotifications|OSLog|XCTest|Trap|ShotTimer|PDFKit|CoreGraphics"`.

## Yearly

Minimum iOS: the app targets iOS 17. Raise it only when App Store Connect's usage page shows the older version under
5 % of the app's own users, and record the decision as an ADR in `docs/architecture.md`.

## Options evaluated here, not before (`phase-9.md`)

iCloud sync (CloudKit mirror of `RoundRecord`), coach sharing (export pack or signed link), Apple Watch status,
Live Activity for the timer, localisation. Each is a one-page note in `docs/options/<name>.md`: the shooter problem it
solves, what it costs in complexity against rule 3 (no accounts, no server), and a recommendation. No code until the
owner picks one.

## Never

- Change the detector from a support complaint. Fixtures first (`/detector-fixtures`).
- Add analytics, crash SDKs or any upload path. MetricKit payloads leave the phone only inside a support bundle the
  shooter chooses to mail.
- Quote a shooter's log lines or round data in a public place; support bundles stay with the owner.
