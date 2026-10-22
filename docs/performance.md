# Performance

## Budgets

| What | Budget | Measured with |
|---|---|---|
| Cold launch to Record screen | < 400 ms on an iPhone 12 | Instruments App Launch, `TrapLog.signposter` `launch` |
| Timer start (tap to first level reading) | < 300 ms | signpost `timer.start` |
| Engine restart after a receiver plug | < 500 ms | signpost `timer.restart` |
| Level meter | 20 Hz normally, 5 Hz when conserving power | `PowerMonitor.levelMeterHz` |
| Round save after a target entry | < 10 ms on the main thread | signpost `data.save` |
| Rounds list, 2,000 rounds | first screen < 50 ms | `fetchSummaries(limit: 60)` column fetch, paging |
| Analysis over 1,000 rounds | < 500 ms | `TrapCoreTests` `measure` |
| CSV of 1,000 rounds (25,000 rows) | < 1 s | `TrapCoreTests` `measure` |
| Memory, steady state while timing | < 60 MB | Instruments Allocations |
| Battery, one hour of timing | < 10 % on an iPhone 15 | Settings → Battery after a range session; MetricKit `cumulativeCPUTime` |

## How the code keeps them

- **Audio thread**: `AudioDetector` allocates nothing per buffer; ring buffers and running sums; one lock; results posted
  as closures to the main queue once per buffer.
- **Lists**: `RoundSummary` column fetches with `propertiesToFetch`, `fetchLimit` and `fetchOffset`; the document is
  decoded only for the detail screen.
- **Caching**: `BreakDistanceModel` builds its shot flight table once per settings; keep one instance per settings in
  the Record model. `Analysis` results are recomputed only when the round list changes (compare `updatedAt` hashes).
- **Lazy loading**: scorecard images and PDFs are rendered on demand with `ImageRenderer`, never kept in memory; the
  Schemes table renders one scheme at a time.
- **Value types**: `Round` is a struct with 25‑slot arrays; copies are cheap and undo is "keep the old value".
- **Memory**: `@ObservationIgnored` on engine objects; weak participants in `LifecycleCoordinator`; recordings written
  straight to disk by `RoundRecorder`'s serial queue.

## Measuring

- Instruments templates: Time Profiler (main thread), Allocations (leaks while timing 30 minutes), Audio System Trace,
  Energy Log. Signposts appear under Points of Interest.
- `xcodebuild test` with `-enablePerformanceTestsDiagnostics YES` keeps baselines for the `measure` tests.
- MetricKit payloads (collected by `MetricsCollector`) report launch time, hang rate and energy per day on real devices.
