import Foundation
import UserNotifications

/// Local notifications only. This app has no server, so there is no remote push and no APNs token (ADR-011).
///
/// One use case: the shooter leaves the app mid-round and does not come back. A quiet reminder after a delay says
/// which session is unfinished. Authorization is requested at that moment, never at launch, and a refusal is final:
/// the app keeps working exactly the same without it.
public protocol LocalNotifying: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    /// Asks once if the status is `.notDetermined`. Returns whether notifications are allowed.
    func requestAuthorizationIfNeeded() async -> Bool
    func scheduleUnfinishedRound(id: String, sessionId: String, targetsLeft: Int, after seconds: TimeInterval) async
    func cancelUnfinishedRound(id: String)
    func cancelAll()
}

public final class LocalNotifier: LocalNotifying {
    public static let unfinishedPrefix = "unfinished-round-"
    public static let roundCategory = "ROUND"
    /// Default delay before the reminder: 20 minutes.
    public static let defaultDelay: TimeInterval = 20 * 60

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        let category = UNNotificationCategory(identifier: LocalNotifier.roundCategory, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    public func requestAuthorizationIfNeeded() async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        @unknown default: return false
        }
    }

    public func scheduleUnfinishedRound(id: String, sessionId: String, targetsLeft: Int, after seconds: TimeInterval = LocalNotifier.defaultDelay) async {
        guard targetsLeft > 0, await requestAuthorizationIfNeeded() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Round not finished"
        content.body = LocalNotifier.body(sessionId: sessionId, targetsLeft: targetsLeft)
        content.categoryIdentifier = LocalNotifier.roundCategory
        content.interruptionLevel = .passive
        content.userInfo = ["roundID": id]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        let request = UNNotificationRequest(identifier: LocalNotifier.unfinishedPrefix + id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    public func cancelUnfinishedRound(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [LocalNotifier.unfinishedPrefix + id])
        center.removeDeliveredNotifications(withIdentifiers: [LocalNotifier.unfinishedPrefix + id])
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    public static func body(sessionId: String, targetsLeft: Int) -> String {
        "\(sessionId.isEmpty ? "Your round" : sessionId) has \(targetsLeft) \(targetsLeft == 1 ? "target" : "targets") left. Open TrapShoot to finish or close it."
    }
}

/// Does nothing. For previews, tests, and when the shooter turned reminders off in Settings.
public final class SilentNotifier: LocalNotifying {
    public init() {}
    public func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    public func requestAuthorizationIfNeeded() async -> Bool { false }
    public func scheduleUnfinishedRound(id: String, sessionId: String, targetsLeft: Int, after seconds: TimeInterval) async {}
    public func cancelUnfinishedRound(id: String) {}
    public func cancelAll() {}
}
