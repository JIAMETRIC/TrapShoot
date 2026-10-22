import XCTest
import ShotTimer
import TrapCore
import TrapData
@testable import TrapApp

/// A timer driven by the test: records what the model asked of it and lets the test send events.
@MainActor
final class ScriptedTimer: ShotTimerControlling {
    var isRunning = false
    var isRecording = false
    var inputs: [AudioInput] = []
    var route = AudioRoute(id: "dji", label: "DJI MIC MINI", isExternal: true)
    var sampleRate: Double = 48_000
    var diagnostics = AudioDiagnostics()
    var voiceDb: Double?
    var peakDb: Double?
    var lastError: String?
    var lastNote: String?
    var lastRecordingURL: URL?
    var settings = TimerSettings()
    var onEvent: ((TimerEvent) -> Void)?
    var commands: [String] = []

    func start(input: AudioInput, record: Bool, sessionName: String) {
        isRunning = true
        onEvent?(.started(route: route, sampleRate: sampleRate, recording: nil))
    }
    func stop() { isRunning = false; commands.append("stop") }
    func apply(_ settings: TimerSettings) { self.settings = settings }
    func arm(beep: Bool, once: Bool) { commands.append(beep ? "beep" : once ? "arm-once" : "arm") }
    func disarm() { commands.append("disarm") }
    func refreshInputs() {}
    func recordingToShare() -> URL? { nil }
    func send(_ e: TimerEvent) { onEvent?(e) }
}

@MainActor
final class RecordFlowTests: XCTestCase {
    private func makeModel(repo: InMemoryRoundRepository? = nil, defaults: UserDefaults? = nil) -> (RecordModel, ScriptedTimer, UserDefaults) {
        let repo = repo ?? InMemoryRoundRepository()          // built here, on the main actor, not in a default argument
        let d = defaults ?? UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let timer = ScriptedTimer()
        var s = AppSettings(); s.profile.name = "Mohammad Tajudeen"
        return (RecordModel(repository: repo, timer: timer, settings: s, defaults: d), timer, d)
    }

    private func fillSetup(_ m: RecordModel) {
        m.updateSetup { r in r.place = "Al Ain"; r.field = 2; r.sky = "sun"; r.temperature = 31; r.humidity = 40 }
    }

    func testStartNeedsTheRangeData() {
        let (m, _, _) = makeModel()
        m.start()
        XCTAssertEqual(m.session.phase, .setup)
        XCTAssertEqual(m.error?.message, "Enter Range, Field, Sky, Temperature, Humidity before you start.")
        fillSetup(m); m.start()
        XCTAssertEqual(m.session.phase, .recording)
        XCTAssertNil(m.error)
        XCTAssertTrue(m.round.sessionId.hasSuffix("-MT"))
    }

    func testRangeFlowTimesEntersAndArmsTheNextTarget() {
        let (m, timer, _) = makeModel()
        fillSetup(m); m.start()
        m.startTimer(input: .systemDefault)
        XCTAssertEqual(m.flow.phase, .armed)
        XCTAssertEqual(m.flow.status, "Target 1 · Station 1. Listening for the call.")
        XCTAssertEqual(timer.commands.last, "arm")

        timer.send(.firstShot(ms: 612.7))
        XCTAssertEqual(m.flow.phase, .timing)
        timer.send(.target(TimedTarget(firstMs: 612.7, secondMs: 1034.0, callDb: 91.24)))
        XCTAssertEqual(m.round.firstShot[0], 0.613)
        XCTAssertEqual(m.round.secondShot[0], 1.034)
        XCTAssertEqual(m.round.callLevel[0], 91.2)
        XCTAssertEqual(m.round.timerMic[0], "DJI MIC MINI")
        XCTAssertEqual(m.flow.phase, .entry)
        XCTAssertEqual(timer.commands.last, "disarm")

        // a shot while the result is being entered is not counted
        timer.send(.target(TimedTarget(firstMs: 480, secondMs: nil, callDb: nil)))
        XCTAssertEqual(m.round.firstShot[0], 0.613)
        XCTAssertNil(m.round.firstShot[1])
        XCTAssertEqual(m.flow.phase, .entry)

        m.record(direction: .right, result: .hitFirst)
        XCTAssertEqual(m.session.index, 1)
        XCTAssertEqual(m.flow.phase, .armed)
        XCTAssertEqual(m.flow.status, "Target 2 · Station 2. Listening for the call.")
        XCTAssertEqual(timer.commands.last, "arm")
    }

    func testNoTargetSkipRetimeAndUndo() {
        let (m, timer, _) = makeModel()
        fillSetup(m); m.start(); m.startTimer(input: .systemDefault)
        timer.send(.target(TimedTarget(firstMs: 700, secondMs: nil, callDb: 88)))
        XCTAssertEqual(m.round.firstShot[0], 0.7)

        m.noTarget()
        XCTAssertNil(m.round.firstShot[0], "NO TARGET clears the target")
        XCTAssertEqual(m.round.noTarget[0], 1)
        XCTAssertEqual(m.flow.phase, .armed, "re-armed for the same target")
        XCTAssertTrue(m.flow.status.hasPrefix("No target. Target 1 stays at station 1. Timer reset."))
        m.undo()
        XCTAssertEqual(m.round.firstShot[0], 0.7, "undo puts the time back")
        XCTAssertEqual(m.round.noTarget[0], 0)

        m.record(direction: .left, result: .lost)            // target 1 done, on to target 2
        m.skip()
        XCTAssertTrue(m.session.skipped.contains(1))
        XCTAssertEqual(m.flow.phase, .entry)
        XCTAssertEqual(timer.commands.last, "disarm")
        m.record(direction: .straight, result: .hitSecond)
        XCTAssertEqual(m.session.index, 2)

        m.select(0)
        XCTAssertEqual(m.flow.phase, .review)
        m.retime()
        XCTAssertNil(m.round.firstShot[0])
        XCTAssertEqual(m.flow.phase, .armed, "a complete target can be timed again")
        timer.send(.target(TimedTarget(firstMs: 655.4, secondMs: nil, callDb: nil)))
        XCTAssertEqual(m.round.firstShot[0], 0.655)
        XCTAssertEqual(m.round.results[0], .lost, "re-timing keeps the result")
    }

    func testTapArmingAndBeep() {
        let (m, timer, _) = makeModel()
        var s = m.settings; s.timing.arming = .tap; m.apply(s)
        fillSetup(m); m.start(); m.startTimer(input: .systemDefault)
        XCTAssertEqual(m.flow.phase, .idle)
        XCTAssertEqual(timer.commands.last, "disarm")
        m.armTapped()
        XCTAssertEqual(timer.commands.last, "arm-once")
        s.timing.startSignal = .beep; m.apply(s)
        m.armTapped()
        XCTAssertEqual(timer.commands.last, "beep")
    }

    func testKillAndResumeReopensTheRound() {
        let repo = InMemoryRoundRepository()
        let (m, timer, d) = makeModel(repo: repo)
        fillSetup(m); m.start(); m.startTimer(input: .systemDefault)
        timer.send(.target(TimedTarget(firstMs: 590, secondMs: nil, callDb: nil)))
        m.record(direction: .right, result: .hitFirst)
        let id = m.round.id

        let (again, _, _) = makeModel(repo: repo, defaults: d)
        XCTAssertEqual(again.round.id, id)
        XCTAssertEqual(again.round.firstShot[0], 0.59)
        XCTAssertEqual(again.round.results[0], .hitFirst)
        XCTAssertEqual(again.session.index, 1)
        XCTAssertEqual(again.session.phase, .recording)
    }

    func testBackgroundStopsTheTimerAndKeepsTheRound() {
        let (m, timer, _) = makeModel()
        fillSetup(m); m.start(); m.startTimer(input: .systemDefault)
        m.enteredBackground()
        XCTAssertFalse(timer.isRunning)
        XCTAssertTrue(m.stoppedInBackground)
        XCTAssertEqual(m.flow.phase, .off)
        XCTAssertEqual(try m.repository.fetch(id: m.round.id)?.place, "Al Ain")
    }
}
