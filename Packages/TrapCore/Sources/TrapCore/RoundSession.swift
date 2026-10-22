import Foundation

/// The round's lifecycle on the range. The Record screen drives this; nothing else mutates a round while it is live.
///
/// ```
///            start()  [guard: range, field, sky, temperature, humidity entered]
///  SETUP ─────────────────────────▶ RECORDING ◀──────────────┐
///    ▲                                  │                     │ reopen() / noTarget() / undo()
///    │ editSetup()  (range data stays   │ last of 25 targets  │
///    │  editable; recording resumes)    ▼                     │
///    └──────────────────────────── COMPLETE ──────────────────┘
/// ```
/// Illegal moves throw a `RoundSessionError` the screen can show; nothing is changed on an error.
public enum RoundPhase: String, Codable, Sendable { case setup, recording, complete }

/// Range data the shooter must enter before the first target (the web app's `checkSetup`).
public enum SetupField: String, CaseIterable, Sendable {
    case range = "Range", field = "Field", sky = "Sky", temperature = "Temperature", humidity = "Humidity"
}

public enum RoundSessionError: Error, Equatable, UserFacingError {
    case missingSetup([SetupField])
    case notRecording
    case directionFull(station: Int, direction: Direction)
    case startStationLocked
    case targetOutOfRange(Int)
    case nothingToUndo

    public var message: String {
        switch self {
        case .missingSetup(let f): return "Enter \(f.map(\.rawValue).joined(separator: ", ")) before you start."
        case .notRecording: return "Start the round before recording targets."
        case .directionFull(let s, let d):
            return "Wrong entry. Station \(s) already has \(d.quota) \(d.name.lowercased()). Each station gets 2 right, 1 straight and 2 left."
        case .startStationLocked: return "The first station cannot change once targets are recorded."
        case .targetOutOfRange(let i): return "There is no target \(i + 1)."
        case .nothingToUndo: return "Nothing to undo."
        }
    }
    public var recovery: String? {
        if case .directionFull = self { return "Check the arrow on your scorecard, or fix an earlier target at this station." }
        return nil
    }
}

/// Everything about one target that an undo must put back.
public struct TargetSnapshot: Equatable, Sendable {
    public var direction: Direction?
    public var result: TargetResult?
    public var firstShot: Double?
    public var secondShot: Double?
    public var callLevel: Double?
    public var timerMic: String
    init(_ r: Round, _ i: Int) {
        direction = r.directions[i]; result = r.results[i]; firstShot = r.firstShot[i]; secondShot = r.secondShot[i]
        callLevel = r.callLevel[i]; timerMic = r.timerMic[i]
    }
    func restore(into r: inout Round, at i: Int) {
        r.directions[i] = direction; r.results[i] = result; r.firstShot[i] = firstShot; r.secondShot[i] = secondShot
        r.callLevel[i] = callLevel; r.timerMic[i] = timerMic
    }
}

public enum UndoEntry: Equatable, Sendable {
    /// Direction or result entered.
    case entry(index: Int, before: TargetSnapshot)
    /// Timer wrote a time.
    case timing(index: Int, before: TargetSnapshot)
    /// NO TARGET cleared the target.
    case noTarget(index: Int, before: TargetSnapshot, wasSkipped: Bool)
    /// Target was skipped for timing.
    case skip(index: Int)

    public var index: Int {
        switch self { case .entry(let i, _), .timing(let i, _), .noTarget(let i, _, _), .skip(let i): return i }
    }
}

/// Aggregate: the round plus its phase, the current target, the timer skip set and a bounded undo stack.
/// A value type: the Record screen keeps one in `@State`/`@Observable`; saving means handing `round` to the repository.
public struct RoundSession: Equatable, Sendable {
    public static let undoLimit = 50

    public private(set) var round: Round
    public private(set) var phase: RoundPhase
    /// Index of the target being entered, 0...24.
    public private(set) var index: Int
    /// Targets the shooter chose not to time.
    public private(set) var skipped: Set<Int> = []
    public private(set) var undoStack: [UndoEntry] = []
    /// True once `start()` succeeded; range data edits after that return to recording, not to a fresh start.
    public private(set) var hasStarted: Bool

    public init(round: Round) {
        self.round = round
        hasStarted = round.hasData
        phase = round.isComplete ? .complete : hasStarted ? .recording : .setup
        index = round.firstIncomplete
    }

    // MARK: setup

    public static func missingSetup(_ r: Round) -> [SetupField] {
        var m: [SetupField] = []
        if r.place.trimmingCharacters(in: .whitespaces).isEmpty { m.append(.range) }
        if r.field == nil { m.append(.field) }
        if r.sky.isEmpty { m.append(.sky) }
        if r.temperature == nil { m.append(.temperature) }
        if r.humidity == nil { m.append(.humidity) }
        return m
    }

    /// Range data and conditions, editable at any time; the start station only before the first target.
    public mutating func updateSetup(_ change: (inout Round) -> Void) throws {
        var r = round
        change(&r)
        if r.startStation != round.startStation && startStationLocked { throw RoundSessionError.startStationLocked }
        round = r
    }

    public var startStationLocked: Bool { round.hasData }

    /// SETUP → RECORDING. Throws `missingSetup` with the fields to fill.
    public mutating func start() throws {
        if !hasStarted {
            let missing = RoundSession.missingSetup(round)
            guard missing.isEmpty else { throw RoundSessionError.missingSetup(missing) }
            hasStarted = true
        }
        phase = round.isComplete ? .complete : .recording
    }

    /// Back to the range data form. Recording resumes with `start()`; no guard the second time.
    public mutating func editSetup() { phase = .setup }

    /// COMPLETE → RECORDING, to change an earlier target.
    public mutating func reopen() { if phase == .complete { phase = .recording } }

    // MARK: targets

    public mutating func select(target i: Int) throws {
        guard (0..<Round.targetCount).contains(i) else { throw RoundSessionError.targetOutOfRange(i) }
        index = i
        if phase == .complete { phase = .recording }
    }
    public mutating func previous() { index = (index + Round.targetCount - 1) % Round.targetCount; reopen() }
    public mutating func next() { index = (index + 1) % Round.targetCount; reopen() }

    /// Enter a direction, a result, or both for the current target. Returns true when this entry completed the round.
    @discardableResult
    public mutating func record(direction: Direction? = nil, result: TargetResult? = nil) throws -> Bool {
        guard phase != .setup else { throw RoundSessionError.notRecording }
        if let d = direction, round.directions[index] != d, round.isFull(at: index, direction: d) {
            throw RoundSessionError.directionFull(station: round.station(at: index), direction: d)
        }
        let wasComplete = round.isComplete
        push(.entry(index: index, before: TargetSnapshot(round, index)))
        if let d = direction { round.directions[index] = d }
        if let s = result { round.results[index] = s }
        if !round.isIncomplete(at: index) { index = round.nextIncomplete(after: index) }
        if round.isComplete && !wasComplete { phase = .complete; return true }
        return false
    }

    /// The timer's result for a target (seconds). Ignored while in setup; the timer is disarmed then.
    public mutating func recordTiming(at i: Int, firstShot: Double?, secondShot: Double?, callLevel: Double?, mic: String) {
        guard (0..<Round.targetCount).contains(i) else { return }
        push(.timing(index: i, before: TargetSnapshot(round, i)))
        round.firstShot[i] = firstShot; round.secondShot[i] = secondShot; round.callLevel[i] = callLevel; round.timerMic[i] = mic
    }

    /// Skip = no time for this target.
    public mutating func skipTiming(at i: Int) {
        guard (0..<Round.targetCount).contains(i), !skipped.contains(i) else { return }
        skipped.insert(i); push(.skip(index: i))
    }
    /// Re-time T# = time the selected target again.
    public mutating func retime(at i: Int) {
        skipped.remove(i)
        recordTiming(at: i, firstShot: nil, secondShot: nil, callLevel: nil, mic: "")
    }

    /// NO TARGET: the clay did not come, came out broken, or the same target again in training.
    /// The target keeps its number and station; direction, result and times clear; the press is counted.
    public mutating func noTarget() {
        let i = index
        push(.noTarget(index: i, before: TargetSnapshot(round, i), wasSkipped: skipped.contains(i)))
        TargetSnapshot.cleared.restore(into: &round, at: i)
        skipped.remove(i)
        round.noTarget[i] = round.noTargetCount(at: i) + 1
        if phase == .complete { phase = .recording }
    }

    /// Puts back the last change and says what it did.
    @discardableResult
    public mutating func undo() throws -> String {
        guard let u = undoStack.popLast() else { throw RoundSessionError.nothingToUndo }
        switch u {
        case .entry(let i, let before):
            before.restore(into: &round, at: i)
            index = i
            if phase == .complete { phase = .recording }
            return "Target \(i + 1) is back as it was."
        case .timing(let i, let before):
            before.restore(into: &round, at: i)
            return "Time removed from target \(i + 1)."
        case .noTarget(let i, let before, let wasSkipped):
            before.restore(into: &round, at: i)
            if wasSkipped { skipped.insert(i) }
            round.noTarget[i] = max(0, round.noTargetCount(at: i) - 1)
            index = i
            if round.isComplete { phase = .complete }
            return "No target undone. Target \(i + 1) is back as it was."
        case .skip(let i):
            skipped.remove(i)
            return "Target \(i + 1) is back in the timing queue."
        }
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var isComplete: Bool { round.isComplete }

    private mutating func push(_ e: UndoEntry) {
        undoStack.append(e)
        if undoStack.count > RoundSession.undoLimit { undoStack.removeFirst(undoStack.count - RoundSession.undoLimit) }
    }
}

extension TargetSnapshot {
    static let cleared: TargetSnapshot = {
        var s = TargetSnapshot(Round(id: "", createdAt: "", date: "", startTime: ""), 0)
        s.timerMic = ""
        return s
    }()
}

public extension Round {
    /// Every target has a direction and a result.
    var isComplete: Bool { !(0..<Round.targetCount).contains { isIncomplete(at: $0) } }
}
