import SwiftUI
import TrapApp

/// TrapShoot. The whole app lives in the TrapApp package (ADR-017); this target only starts it.
@main
struct TrapShooterProApp: App {
    var body: some Scene {
        WindowGroup {
            TrapAppRoot()
        }
    }
}
