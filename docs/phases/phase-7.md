# Phase 7 — Settings, data and platform behaviours `[CMS · SD · SEF]`

- Settings: profile (name, DOB, weapon, ammo, chokes), timer defaults, break distance, weather auto‑fill, reminders on/off,
  appearance follows system.
- Data: storage report, recordings list with delete and purge older than 30 days, backup export (`BackupFile`),
  restore/import with `ImportReport`, one‑time import of the shooter's 7.x rounds (from a Supabase table export file).
- About: version line, channel, Send diagnostics (`SupportBundle`), hidden debug screen (`docs/debugging.md`).
- Platform: `LifecycleCoordinator`, `PowerMonitor` advice on the Timer screen, `NetworkMonitor` gating weather,
  `LocalNotifier` unfinished‑round reminder, `MetricsCollector.start()` at launch.
- Clean break: delete `Web/`, `supabase.js`, `config.js`, the hybrid Swift files; remove the folder reference from the
  project; CI's "hybrid shell" step becomes the native build.

**Exit gate:** export a backup, delete the app, reinstall, restore: identical library; background mid‑round → timer
stopped, round saved, reminder arrives after 20 minutes if not reopened; Low Data Mode blocks automatic weather and allows
the manual button; the repository contains no JavaScript.
