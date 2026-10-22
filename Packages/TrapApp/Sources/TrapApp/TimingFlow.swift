import Foundation
import TrapCore

/// How the timer is started for each target (Timer settings > Start signal and Arming). Same choices as 7.0.7.
public struct TimingPreferences: Equatable, Codable, Sendable {
    public enum StartSignal: String, Codable, CaseIterable, Sendable { case voice, beep }
    public enum Arming: String, Codable, CaseIterable, Sendable { case auto, tap }
    public var startSignal: StartSignal = .voice
    public var arming: Arming = .auto
    public init() {}
}

/// What the detector should do after a step of the flow.
enum TimerCommand: Equatable {
    case none
    case arm(beep: Bool, once: Bool)
    case disarm
}

/// Which target the next time goes to, and what the timer is waiting for. A port of the 7.0.7 page's live timing
/// (`slot`, `waitState`, `arm`, `onFirst`, `onTarget`, `skip`, `here`, `noTarget`): live timing is locked to the target
/// on screen; after its call and shots the timer stops listening until direction and result are entered, then arms
/// for the next open target. Shots fired while a result is being entered are therefore never counted.
/// Pure: the Record model applies the commands to the timer and the times to the `RoundSession`.
struct TimingFlow: Equatable {
    enum Phase: Equatable {
        /// Timer not running.
        case off
        /// Round not started yet.
        case wait
        /// Tap arming: waiting for the scorer to tap Arm.
        case idle
        /// Listening for the call.
        case armed
        /// Call and 1st shot heard, waiting for a 2nd shot.
        case timing
        /// The target on screen has its time (or none); waiting for direction and result.
        case entry
        /// The target on screen is complete; the scorer moves on or re-times it.
        case review
        /// All 25 targets recorded.
        case done
    }

    private(set) var phase: Phase = .off
    /// The line under the timer.
    private(set) var status = "Shot timer off."
    /// Re-time: the target that takes a time even though it is complete.
    private(set) var forced: Int?
    /// The target the call and 1st shot belong to, fixed when the 1st shot is heard.
    private(set) var timingFor: Int?
    /// When NO TARGET was pressed; events within 400 ms belong to the cleared clay and are dropped.
    private(set) var noTargetAt: Date?
    var preferences = TimingPreferences()

    // MARK: rules

    /// The target that can take a time now, or nil. `slot()` in the page.
    func slot(_ s: RoundSession) -> Int? {
        let i = s.index, r = s.round
        if r.firstShot[i] != nil || s.skipped.contains(i) { return nil }
        return r.isIncomplete(at: i) || forced == i ? i : nil
    }

    /// What the timer waits for when no target can take a time. `waitState()` in the page.
    func waitPhase(_ s: RoundSession) -> Phase {
        guard s.hasStarted else { return .wait }
        if s.round.isComplete { return .done }
        let i = s.index
        if (s.round.firstShot[i] != nil || s.skipped.contains(i)) && s.round.isIncomplete(at: i) { return .entry }
        return .review
    }

    static func slotText(_ i: Int, _ r: Round) -> String { "Target \(i + 1) · Station \(r.station(at: i))" }

    func waitMessage(_ p: Phase, _ s: RoundSession) -> String {
        let i = s.index
        switch p {
        case .done: return "All 25 targets recorded."
        case .entry: return "Target \(i + 1)" + (s.round.firstShot[i] != nil ? " timed." : ": no time.") + " Enter direction and result. The timer then arms for the next target."
        case .review: return "Target \(i + 1) is complete. Tap Time T\(i + 1) to time it again, or go to an open target."
        default: return "Start the round. Timing begins at the first call."
        }
    }

    // MARK: steps

    mutating func timerStopped() {
        phase = .off; timingFor = nil; status = "Shot timer off."
    }

    /// Arms for the target on screen, or says what the timer waits for. `manual` is a tap on Arm.
    mutating func arm(_ s: RoundSession, manual: Bool = false, running: Bool) -> TimerCommand {
        guard running else { phase = .off; return .none }
        timingFor = nil
        guard s.hasStarted, let t = slot(s) else {
            phase = waitPhase(s); status = waitMessage(phase, s)
            return .disarm
        }
        let label = Self.slotText(t, s.round)
        if preferences.arming == .tap && !manual {
            phase = .idle; status = label + ". Tap Arm when the athlete is ready."
            return .disarm
        }
        phase = .armed
        if preferences.startSignal == .beep {
            status = label + ". Beep in 1.5 to 3.5 s."
            return .arm(beep: true, once: true)
        }
        status = label + ". Listening for the call."
        return .arm(beep: false, once: preferences.arming == .tap)
    }

    /// The detector heard the call and a 1st shot.
    mutating func firstShot(ms: Double, _ s: RoundSession, now: Date = Date()) {
        if let nt = noTargetAt, now.timeIntervalSince(nt) < 0.4 { return }
        phase = .timing
        timingFor = slot(s)
        status = (timingFor.map { "Target \($0 + 1): " } ?? "") + "1st shot " + JSText.fixed(ms / 1000, 3) + " s. Waiting for a 2nd shot."
    }

    /// Where a finished target's times go. Nil means: drop them and re-arm (`.arm` in the returned command).
    struct Placement: Equatable {
        let index: Int
        let firstShot: Double
        let secondShot: Double?
        let callLevel: Double?
    }

    /// The detector finished a target. Returns where the times go (the caller records them in the session) and the
    /// command for the detector. Call `afterTiming` with the updated session to finish the step.
    mutating func target(firstMs: Double, secondMs: Double?, callDb: Double?, _ s: RoundSession, now: Date = Date()) -> (Placement?, TimerCommand) {
        guard s.hasStarted else { phase = .wait; status = waitMessage(.wait, s); return (nil, .disarm) }
        if let nt = noTargetAt, now.timeIntervalSince(nt) < 0.4 { return (nil, .none) }
        let target = timingFor ?? slot(s)
        timingFor = nil
        guard let i = target, s.round.firstShot[i] == nil else { return (nil, arm(s, running: true)) }
        // the page's r3(t / 1000) and Math.round(callDb * 10) / 10
        let seconds = { (ms: Double) in JSMath.round(ms / 1000 * 1000) / 1000 }
        let level = callDb.flatMap { $0.isFinite ? JSMath.round($0 * 10) / 10 : nil }
        forced = nil
        return (Placement(index: i, firstShot: seconds(firstMs), secondShot: secondMs.map(seconds), callLevel: level), .disarm)
    }

    /// Second half of `target`: the session now holds the times of `placed`.
    mutating func afterTiming(placed: Int, _ s: RoundSession) -> TimerCommand {
        let r = s.round
        let done = "Target \(placed + 1): " + JSText.fixed(r.firstShot[placed] ?? 0, 3) + " s"
            + (r.secondShot[placed].map { ", 2nd " + JSText.fixed($0, 3) + " s" } ?? "") + ". "
        if placed != s.index, slot(s) != nil {
            // the scorer already entered this target and moved on: arm for the target on screen
            let c = arm(s, running: true)
            status = done + status
            return c
        }
        let i = s.index
        phase = !r.isIncomplete(at: i) ? (r.isComplete ? .done : .review) : .entry
        status = done + (phase == .entry ? "Enter direction and result." : phase == .review ? "Go to the next open target." : "")
        return .disarm
    }

    /// Skip: no time for the target on screen. The caller marks it skipped in the session first.
    mutating func skipped(_ index: Int) -> TimerCommand {
        phase = .entry
        status = "Target \(index + 1): no time. Enter direction and result."
        return .disarm
    }

    /// Re-time T#: the caller cleared the target's times in the session; time it again even if complete.
    mutating func retime(_ s: RoundSession, running: Bool) -> TimerCommand {
        forced = s.index
        return arm(s, manual: true, running: running)
    }

    /// NO TARGET: drop what the detector heard and re-arm for the same target. The caller cleared the target.
    mutating func noTarget(_ s: RoundSession, running: Bool, now: Date = Date()) -> TimerCommand {
        timingFor = nil; forced = nil; noTargetAt = now
        let i = s.index
        let said = "No target. Target \(i + 1) stays at station \(s.round.station(at: i))."
        guard running else { status = said + " Record it when the clay is thrown."; return .none }
        let c = arm(s, running: true)
        status = said + " Timer reset. " + status
        return c
    }

    /// Any other change on the Record screen (entry, undo, moving between targets).
    mutating func changed(_ s: RoundSession, running: Bool) -> TimerCommand {
        if phase == .timing { return .none }          // a target is being timed; its result arrives next
        return arm(s, running: running)
    }

    /// Undo of a timing or skip on the target on screen makes it take a time again.
    mutating func undid(index: Int, _ s: RoundSession, running: Bool) -> TimerCommand {
        if index == s.index { forced = index }
        return changed(s, running: running)
    }
}
