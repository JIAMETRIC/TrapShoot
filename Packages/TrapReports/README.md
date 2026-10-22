# TrapReports

| Type | Input | Format | Notes |
|---|---|---|---|
| `CSVRoundsExporter` | `[Round]` | csv | the frozen CSV layout (`CSVExport`), formula‑safe |
| `SingleRoundCSVExporter` | `Round` | csv | same, one round |
| `BackupExporter` | `[Round]` | json | restorable library file (`Backup`) |
| `ScorecardImageExporter` | `Round` | png | `ScorecardView` through `ImageRenderer` at 2× |
| `ScorecardPDFExporter` | `Round` | pdf | `ScorecardView` into `UIGraphicsPDFRenderer`: vector text |

`DocumentExporter<Input>` is the protocol; `export(_:to:)` is the template method (bytes → safe file name → atomic
write → `ExportResult`). `ExporterFactory.formats(for:)` says what a screen offers and returns the right exporter.
Screens hand the `ExportResult.url` to `ShareLink`.

Tests (`TrapReportsTests`, simulator): file names, CSV and backup exporters with the template‑method write, the factory, the condition line, and a render smoke test for PNG and PDF.
