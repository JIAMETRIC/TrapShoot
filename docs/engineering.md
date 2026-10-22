# Engineering foundations, in this app's terms

The eight foundations and what each one is here. Code first; a decision record where a topic does not apply.

| Foundation | In TrapShooterPro | Where |
|---|---|---|
| Databases | SwiftData store, one table with indexed columns and a document payload; versioned schema (one version today) with a migration plan; filtered, paged summary queries; all‑or‑nothing batch writes; UserDefaults as the key‑value store; no NoSQL server because there is no server | `Packages/TrapData` (`Schema.swift`, `Queries.swift`), ADR‑003 |
| APIs and networking | One REST GET over HTTPS (Open‑Meteo), typed endpoint, retry with backoff for transient failures only, stubbed integration tests; no auth, GraphQL or WebSockets because the app has no backend | `Packages/TrapWeather` (`HTTPClient.swift`), ADR‑014, `docs/security.md` |
| Version control | Trunk‑based Git, short branches, pull requests with a template, CI on every PR, tags for TestFlight builds, union merge for the Xcode project file | `docs/git-workflow.md`, `.github/`, `.gitattributes` |
| Testing | Golden tests against the JavaScript, unit tests per package, SwiftData integration tests in memory, HTTP tests through a stub protocol, performance tests with budgets, detector regression on recordings, UI tests planned with stable identifiers | `docs/testing.md`, every `Tests/` folder |
| Security | OWASP Mobile Top 10 mapped; input validation and sanitising on every import; CSV formula‑injection protection; no credentials, so nothing to hash or keep in the Keychain; file protection; ATS‑default HTTPS; privacy manifest | `docs/security.md`, `TrapCore/Validation.swift`, `CSVExport.cell` |
| DevOps | GitHub Actions: fixtures‑current, `swift test` on macOS, simulator build and tests; manual TestFlight workflow; no Docker (iOS builds need macOS); logging with `os.Logger`, signposts, MetricKit, support bundle | `.github/workflows/`, `TrapPlatform/Diagnostics.swift`, `Scripts/archive.sh` |
| Performance | Budgets and how to measure them; signposts for Instruments; column fetches and paging for lists; cached shot table; value types and zero allocation on the audio thread | `docs/performance.md`, `TrapCore` performance tests |
| Error handling and debugging | `UserFacingError` for anything a screen shows; sanitise‑then‑report on import; log categories with privacy annotations; support bundle instead of screenshots; debug screen spec | `docs/debugging.md`, `TrapCore/Errors.swift` |

Decisions added with this work: ADR‑014 (no backend, no auth), ADR‑015 (CI gates), ADR‑016 (diagnostics without SDKs) in `docs/architecture.md`.
