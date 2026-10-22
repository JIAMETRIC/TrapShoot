# Phase 6 — Rounds, Analysis, Schemes and exporters `[DSA · TAB · SEF]`

- Rounds: `fetchSummaries` with `RoundFilter` (search field, scheme and type chips, date range), paging by 60, swipe to
  delete with undo, master‑detail on iPad (`AdaptiveSplit`), detail shows the scorecard view live.
- Analysis: overview tiles (`BWKPITile`, `Breakpoint.tileColumns`), trend bars, dimension tables, trap analysis with
  findings, scheme picker.
- Schemes: table of 15 machines per scheme, ink header, one scheme at a time.
- Exporters (`TrapReports`): PNG and PDF scorecard, CSV of one round or a filtered list, library backup; all through
  `ExporterFactory` and `ShareLink`; temp files removed after sharing.

**Exit gate:** 2,000 rounds: list first screen under 50 ms, search under 100 ms; scorecard PDF text selectable in
Preview; CSV for a fixture round identical to the web app's bytes (golden test already covers the text; the file on disk
is compared once); analysis of 1,000 rounds under 500 ms on device.
