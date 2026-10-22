# Phase 9 — Operate and iterate `[all]`

**Service levels (no server, so measured on device)**

| Metric | Target | Source |
|---|---|---|
| Crash‑free sessions | > 99.5 % | MetricKit diagnostics in support bundles; App Store Connect crashes |
| Hang rate | < 1 per 100 sessions | MetricKit `MXAppResponsivenessMetric` |
| Cold launch p95 | < 400 ms | MetricKit `MXAppLaunchMetric` |
| Timer accuracy | within 7 ms of reference | regression set on every release |
| Support bundles answered | within 2 days | mailbox |

**Cadence:** weekly App Store review triage; per iOS beta a run on the regression set and the UI test; quarterly
dependency‑free security review (`docs/security.md`); yearly minimum‑iOS decision.

**Options evaluated here, not before:** iCloud sync (CloudKit mirror of `RoundRecord`), coach sharing (export pack or
signed link), Apple Watch status, Live Activity for the timer, localisation.
