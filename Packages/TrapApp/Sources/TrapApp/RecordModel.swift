import Foundation
import Observation
import ShotTimer
import TrapCore
import TrapData
import TrapPlatform

/// The Record and Timer screens' model. Owns the live `RoundSession`, saves after every entry, feeds timer results
/// into the round through `TimingFlow`, and keeps the flow and the detector in step (7.0.7 range flow, CLAUDE.md rule 6).
@MainActor
@Observable
final class RecordModel {
    private(set) var session: RoundSession
    private(set) var flow = TimingFlow()
    /// The last call‑to‑shot times shown on the readout, seconds.
    private(set) var readout: (first: Double, second: Double?)?
    /// One line of feedback under the entry (undo, NO TARGET, errors).
    private(set) var message: String?
    private(set) var error: DisplayError?
    /// Counts of rejected sounds since the timer started.
    private(set) var rejected: [RejectReason: Int] = [:]
    /// Set when the timer stopped because the app went to the background.
    private(set) var stoppedInBackground = false

    @ObservationIgnored let repository: RoundRepository
    @ObservationIgnored let timer: ShotTimerControlling
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private(set) var settings: AppSettings

    init(repository: RoundRepository, timer: ShotTimerControlling, settings: AppSettings, defaults: UserDefaults = .standard) {
        self.repository = repository
        self.timer = timer
        self.settings = settings
        self.defaults = defaults
        // kill-and-resume: reopen the round that was being recorded
        let saved = defaults.string(forKey: AppState.currentRoundKey).flatMap { try? repository.fetch(id: $0) }
        session = RoundSession(round: saved ?? Round.new())
        flow.preferences = settings.timing
        if saved == nil { session = RoundSession(round: freshRound()) }
        timer.apply(settings.timer)
        timer.onEvent = { [weak self] e in self?.handle(e) }
    }

    var round: Round { session.round }
    var isTimerRunning: Bool { timer.isRunning }

    // MARK: rounds

    func apply(_ s: AppSettings) {
        settings = s
        flow.preferences = s.timing
        timer.apply(s.timer)
    }

    /// Starts a new round with the profile's defaults. The unfinished one stays saved in Rounds.
    func newRound() {
        session = RoundSession(round: freshRound())
        readout = nil; message = nil; error = nil
        persist()
        command(flow.changed(session, running: timer.isRunning))
    }

    /// Opens a saved round for editing on the Record screen.
    func open(id: String) {
        guard let r = try? repository.fetch(id: id) else { error = DisplayError("That round could not be opened."); return }
        session = RoundSession(round: r)
        readout = nil; message = nil
        defaults.set(r.id, forKey: AppState.currentRoundKey)
        command(flow.changed(session, running: timer.isRunning))
    }

    private func freshRound() -> Round {
        var r = (try? repository.makeRound(now: Date(), shooter: settings.profile.name)) ?? Round.new()
        r.shooter = settings.profile.name
        r.weapon = settings.profile.weapon; r.ammo = settings.profile.ammo
        r.choke1 = settings.profile.choke1; r.choke2 = settings.profile.choke2
        r.scheme = settings.defaultScheme; r.type = settings.defaultType
        r.appVersion = AppInfo.version
        return r
    }

    // MARK: setup

    func updateSetup(_ change: (inout Round) -> Void) {
        do { try session.updateSetup(change); error = nil; persist() } catch { show(error) }
    }

    /// SETUP → RECORDING. Says which fields are missing.
    func start() {
        do {
            try session.start(); error = nil; persist()
            command(flow.changed(session, running: timer.isRunning))
        } catch { show(error) }
    }

    func editSetup() { session.editSetup() }

    // MARK: entry

    func record(direction: Direction? = nil, result: TargetResult? = nil) {
        do {
            let completed = try session.record(direction: direction, result: result)
            error = nil; message = completed ? "Round complete: \(round.score) of 25." : nil
            persist()
            command(flow.changed(session, running: timer.isRunning))
        } catch { show(error) }
    }

    func select(_ i: Int) {
        do { try session.select(target: i); error = nil; command(flow.changed(session, running: timer.isRunning)) } catch { show(error) }
    }
    func previous() { session.previous(); command(flow.changed(session, running: timer.isRunning)) }
    func next() { session.next(); command(flow.changed(session, running: timer.isRunning)) }

    func noTarget() {
        session.noTarget()
        readout = nil; error = nil
        persist()
        command(flow.noTarget(session, running: timer.isRunning))
        message = flow.status
    }

    func undo() {
        let index = session.undoStack.last?.index
        do {
            message = try session.undo(); error = nil
            persist()
            command(flow.undid(index: index ?? session.index, session, running: timer.isRunning))
        } catch { show(error) }
    }

    /// Skip: no time for the target on screen.
    func skip() {
        guard let i = flow.slot(session) else { return }
        session.skipTiming(at: i)
        command(flow.skipped(i))
    }

    /// Re-time T#: clear the time of the target on screen and time it again.
    func retime() {
        session.retime(at: session.index)
        readout = nil
        persist()
        command(flow.retime(session, running: timer.isRunning))
    }

    // MARK: timer

    func startTimer(input: AudioInput) {
        stoppedInBackground = false
        rejected = [:]
        timer.start(input: input, record: settings.roundAudio, sessionName: round.sessionId.isEmpty ? "round" : round.sessionId)
    }

    func stopTimer() {
        timer.stop()
        flow.timerStopped()
    }

    /// Tap arming: the scorer taps Arm when the athlete is ready.
    func armTapped() { command(flow.arm(session, manual: true, running: timer.isRunning)) }

    func handle(_ e: TimerEvent) {
        switch e {
        case .started:
            command(flow.arm(session, running: true))
        case .restarted:
            if flow.phase == .armed { command(flow.arm(session, running: true)) }
        case .firstShot(let ms):
            flow.firstShot(ms: ms, session)
            readout = (ms / 1000, nil)
        case .target(let t):
            let (placement, cmd) = flow.target(firstMs: t.firstMs, secondMs: t.secondMs, callDb: t.callDb, session)
            command(cmd)
            guard let p = placement else { return }
            session.recordTiming(at: p.index, firstShot: p.firstShot, secondShot: p.secondShot, callLevel: p.callLevel, mic: timer.route.label)
            readout = (p.firstShot, p.secondShot)
            persist()
            command(flow.afterTiming(placed: p.index, session))
        case .rejected(let r):
            rejected[r, default: 0] += 1
        case .error(let m):
            flow.timerStopped()
            error = DisplayError(m)
        default:
            break
        }
    }

    private func command(_ c: TimerCommand) {
        switch c {
        case .none: break
        case .disarm: timer.disarm()
        case .arm(let beep, let once): timer.arm(beep: beep, once: once)
        }
    }

    // MARK: lifecycle

    /// Background: stop timing, keep the round (ADR-010).
    func enteredBackground() {
        persist()
        if timer.isRunning { stopTimer(); stoppedInBackground = true }
    }

    func acknowledgeBackgroundStop() { stoppedInBackground = false }

    // MARK: saving

    /// Autosave after every entry. Saves a sanitised copy; the screen keeps what the shooter typed.
    func persist() {
        do {
            try repository.save(Validation.sanitized(session.round))
            defaults.set(session.round.id, forKey: AppState.currentRoundKey)
        } catch {
            show(error)
        }
    }

    private func show(_ e: Error) { error = DisplayError(any: e) }
}
