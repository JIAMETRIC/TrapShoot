# TrapPlatform

Mobile-platform concerns, out of the screens and out of the domain. iOS only; run its tests in the simulator.

| Concern | Type | Policy |
|---|---|---|
| App lifecycle | `LifecycleCoordinator`, `LifecycleParticipant`, `View.lifecycle(_:)`, `ScreenAwake` | save on resign active; stop timer and recording on background (no background audio mode); refresh inputs on foreground |
| Battery and heat | `PowerMonitor` | conserve under 20 % / Low Power Mode / hot: slower level meter, round audio off by default; critical under 10 % or too hot |
| Network | `NetworkMonitor` | automatic weather fill only on a reachable, unconstrained path; manual taps on any reachable path |
| Notifications | `LocalNotifier`, `SilentNotifier` | local only, one reminder for an unfinished round, permission asked at that moment, never at launch |
| Storage | `AppPaths`, `RecordingsStore`, `StorageReport`, `CodableDefaults` | file protection after first unlock; recordings listed, deletable, warn under 200 MB free |
| Identity | `AppInfo` | version, build, channel (Debug / TestFlight / App Store) |

## Wiring (app target)

```swift
@main struct TrapShooterProApp: App {
    @State private var lifecycle = LifecycleCoordinator()
    @State private var power = PowerMonitor()
    @State private var network = NetworkMonitor()
    var body: some Scene {
        WindowGroup {
            RootView()
                .lifecycle(lifecycle)
                .environment(lifecycle).environment(power).environment(network)
        }
    }
}

/// Adapter in the app: the timer package does not know about lifecycle.
@MainActor final class TimerLifecycle: LifecycleParticipant {
    let timer: TimerSession, lifecycle: LifecycleCoordinator, save: () -> Void
    func appWillResignActive() { save() }
    func appDidEnterBackground() {
        lifecycle.finishInBackground("stop-timer") { [timer, save] in
            timer.stop()                      // closes the recording on the recorder's queue
            try? await Task.sleep(for: .milliseconds(300))   // let the file finalise before the task ends
            save()
            ScreenAwake.shared.release("timer")
        }
    }
    func appWillEnterForeground() { timer.refreshInputs() }
}

/// The app, not the timer, keeps the screen awake: hold on `.started`, release on `stop()` and on background.
```
```
