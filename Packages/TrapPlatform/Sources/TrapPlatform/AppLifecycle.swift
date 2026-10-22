import SwiftUI
import UIKit

/// Something that wants to know when the app changes state. All methods have empty defaults.
///
/// Policy for this app (ADR-010):
/// - `appWillResignActive` (control centre, incoming call banner, app switcher): **save** the current round. Timing keeps running.
/// - `appDidEnterBackground` (home, lock, another app): **stop the timer and end the recording**. There is no background
///   audio mode; a shot timer that listens while hidden would be wrong for privacy and for the battery. Finish the file
///   writes inside a short background task so nothing is cut off.
/// - `appWillEnterForeground`: refresh the input list (a receiver may have been plugged in meanwhile).
/// - `appDidBecomeActive`: tell the shooter the timer stopped, if it did, and offer Start again.
@MainActor
public protocol LifecycleParticipant: AnyObject {
    func appWillResignActive()
    func appDidEnterBackground()
    func appWillEnterForeground()
    func appDidBecomeActive()
}

public extension LifecycleParticipant {
    func appWillResignActive() {}
    func appDidEnterBackground() {}
    func appWillEnterForeground() {}
    func appDidBecomeActive() {}
}

/// Turns SwiftUI `ScenePhase` changes into the four lifecycle calls, in order, and runs short background tasks.
@MainActor
@Observable
public final class LifecycleCoordinator {
    public private(set) var phase: ScenePhase = .inactive
    public private(set) var launchedAt = Date()
    public private(set) var lastBackgroundedAt: Date?
    public private(set) var lastForegroundedAt: Date?
    /// True after a background → foreground cycle until the app reads it (for "the timer stopped while you were away").
    public var returnedFromBackground = false

    private struct Weak { weak var value: LifecycleParticipant? }
    @ObservationIgnored private var participants: [Weak] = []

    public init() {}

    public func add(_ p: LifecycleParticipant) {
        participants.removeAll { $0.value == nil }
        participants.append(Weak(value: p))
    }

    private var live: [LifecycleParticipant] { participants.compactMap(\.value) }

    /// Call with every scene phase change (see `View.lifecycle(_:)`).
    public func handle(_ new: ScenePhase) {
        let old = phase
        guard new != old else { return }
        phase = new
        switch (old, new) {
        case (.active, .inactive):
            live.forEach { $0.appWillResignActive() }
        case (_, .background):
            lastBackgroundedAt = Date()
            live.forEach { $0.appDidEnterBackground() }
        case (.background, .inactive):
            lastForegroundedAt = Date()
            returnedFromBackground = true
            live.forEach { $0.appWillEnterForeground() }
        case (_, .active):
            if old == .background { lastForegroundedAt = Date(); returnedFromBackground = true; live.forEach { $0.appWillEnterForeground() } }
            live.forEach { $0.appDidBecomeActive() }
        default:
            break
        }
    }

    /// Runs `work` under a UIKit background task so file writes and the final save finish after the app is hidden.
    /// Keep it short (well under 30 s); the system ends it otherwise.
    public func finishInBackground(_ name: String, _ work: @escaping @MainActor () -> Void) {
        var id: UIBackgroundTaskIdentifier = .invalid
        id = UIApplication.shared.beginBackgroundTask(withName: name) {
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
        work()
        if id != .invalid { UIApplication.shared.endBackgroundTask(id) }
    }
}

/// Wires the scene phase to a coordinator. Apply once at the root view.
public struct LifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let coordinator: LifecycleCoordinator
    public func body(content: Content) -> some View {
        content.onChange(of: scenePhase, initial: true) { _, new in coordinator.handle(new) }
    }
}

public extension View {
    func lifecycle(_ coordinator: LifecycleCoordinator) -> some View { modifier(LifecycleModifier(coordinator: coordinator)) }
}

/// Keeps the screen awake only while something needs it (the running timer). Reference-counted so two
/// owners cannot fight over `isIdleTimerDisabled`.
@MainActor
public final class ScreenAwake {
    public static let shared = ScreenAwake()
    private var holders = Set<String>()
    private init() {}
    public func hold(_ owner: String) { holders.insert(owner); apply() }
    public func release(_ owner: String) { holders.remove(owner); apply() }
    private func apply() { UIApplication.shared.isIdleTimerDisabled = !holders.isEmpty }
}
