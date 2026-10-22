# Phase 3 — Local store and repositories `[SD · DSA · CMS · SEF]` — done, verification on the Mac pending

`Packages/TrapData`.

| Deliverable | Status |
|---|---|
| `RoundRepository` protocol; in‑memory and SwiftData implementations | ✅ |
| `RoundRecord` with indexed columns + document payload; `TrapSchemaV1` → `TrapSchemaV2` (adds `place`), lightweight migration, `backfill()` | ✅ |
| `RoundSummary` column fetches, `RoundFilter` (scheme, type, dates, full only, text search), paging, `fetchCount` | ✅ |
| `saveMany` as one transaction with rollback | ✅ |
| `Backup` (encode/decode), `BackupFile` (Transferable), `Importer` for every 7.x shape, `ImportReport` with validation | ✅ |
| Tests: CRUD, filters, paging, search, transaction, backup round trip, importer shapes | ✅ |

**Exit gate:** `swift test --package-path Packages/TrapData` green; a store created with the V1 schema (build 8) opens
under V2 with `place` backfilled (manual check: build 8 on device, record a round, install the V2 build, open Rounds);
2,000 rounds: `fetchSummaries(limit: 60)` under 50 ms on an iPhone 12 (measure with a signpost).
