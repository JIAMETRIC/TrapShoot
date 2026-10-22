# Phase 3 — Local store and repositories `[SD · DSA · CMS · SEF]` — done; `swift test` green in CI, 2,000‑round timing on device pending

`Packages/TrapData`.

| Deliverable | Status |
|---|---|
| `RoundRepository` protocol; in‑memory and SwiftData implementations | ✅ |
| `RoundRecord` with indexed columns + document payload (`place` included); `TrapSchemaV1` as the single version, `TrapMigrationPlan` ready for V2 | ✅ |
| `RoundSummary` column fetches, `RoundFilter` (scheme, type, dates, full only, text search), paging, `fetchCount` | ✅ |
| `saveMany` as one transaction with rollback | ✅ |
| `Backup` (encode/decode), `BackupFile` (Transferable), `Importer` for every 7.x shape, `ImportReport` with validation | ✅ |
| Tests: CRUD, filters, paging, search, transaction, backup round trip, importer shapes | ✅ |

The first CI run caught a crash: `JSONSerialization` raises an Objective‑C exception on NaN, which skipped the
`saveMany` rollback. Encoding now goes through `RoundDocument.jsonData`, which throws `RoundDocumentError.notEncodable`.

**Exit gate:** `swift test --package-path Packages/TrapData` green (including the rollback test); 2,000 rounds: `fetchSummaries(limit: 60)` under 50 ms on an iPhone 12 (measure with a signpost).
