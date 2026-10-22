import SwiftUI

/// TRAP SHOOTER PRO for iPhone.
/// The round recorder runs as a web page inside the app (Web/index.html).
/// The microphone runs natively (MicStreamer) and streams samples to the page's shot timer.
@main
struct TrapShooterProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
