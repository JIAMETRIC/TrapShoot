import Foundation
import Observation
import ShotTimer
import SwiftData
import TrapCore
import TrapData
import TrapPlatform
import TrapWeather

/// The app's object graph, built once at launch: the store, the timer, the monitors and the screen models.
/// Platform behaviour (ADR-010…012) is wired here, not in views.
@MainActor
@Observable
final class AppModel: LifecycleParticipant {
    let record: RecordModel
    let weather: WeatherModel
    let lifecycle = LifecycleCoordinator()
    let power = PowerMonitor()
    let network = NetworkMonitor()
    private(set) var settings: AppSettings
    /// Set when the store could not open; the app runs on an in-memory store and says so.
    private(set) var storeProblem: String?
    /// Bumped whenever rounds change outside the Record screen (import, delete), so lists reload.
    private(set) var libraryVersion = 0

    @ObservationIgnored let repository: RoundRepository
    @ObservationIgnored let container: ModelContainer?
    @ObservationIgnored let timer: ShotTimerControlling
    @ObservationIgnored let notifier: LocalNotifying

    init() {
        let settings = AppSettings.store.load()
        self.settings = settings
        var problem: String?
        do {
            let c = try SwiftDataRoundRepository.container()
            container = c
            repository = SwiftDataRoundRepository(context: c.mainContext)
        } catch {
            TrapLog.data.error("store failed to open: \(error.localizedDescription, privacy: .public)")
            container = nil
            repository = InMemoryRoundRepository()
            problem = "Your rounds could not be opened. New rounds are kept only until the app closes. Restart the phone, then open the app again."
        }
        storeProblem = problem
        timer = TimerSession()
        notifier = LocalNotifier()
        record = RecordModel(repository: repository, timer: timer, settings: settings)
        weather = WeatherModel()
        lifecycle.add(self)
        MetricsCollector.shared.start()
    }

    /// Previews and UI tests: an in-memory store and a scripted timer.
    init(repository: RoundRepository, timer: ShotTimerControlling, settings: AppSettings = AppSettings()) {
        self.settings = settings
        self.repository = repository
        container = nil
        self.timer = timer
        notifier = SilentNotifier()
        record = RecordModel(repository: repository, timer: timer, settings: settings, defaults: UserDefaults(suiteName: "preview") ?? .standard)
        weather = WeatherModel()
        lifecycle.add(self)
    }

    func update(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        guard s != settings else { return }
        settings = s
        AppSettings.store.save(s)
        record.apply(s)
    }

    func libraryChanged() { libraryVersion += 1 }

    // MARK: LifecycleParticipant (ADR-010, ADR-011)

    func appWillResignActive() { record.persist() }

    func appDidEnterBackground() {
        let r = record.round
        let unfinished = r.hasData && !r.isComplete
        lifecycle.finishInBackground("save round") { [record] in record.enteredBackground() }
        ScreenAwake.shared.release("timer")
        guard unfinished, settings.unfinishedReminder else { return }
        let n = notifier
        Task {
            guard await n.requestAuthorizationIfNeeded() else { return }
            await n.scheduleUnfinishedRound(id: r.id, sessionId: r.sessionId, targetsLeft: Round.targetCount - r.recorded, after: LocalNotifier.defaultDelay)
        }
    }

    func appWillEnterForeground() {
        notifier.cancelUnfinishedRound(id: record.round.id)
        timer.refreshInputs()
        power.refresh()
    }
}
