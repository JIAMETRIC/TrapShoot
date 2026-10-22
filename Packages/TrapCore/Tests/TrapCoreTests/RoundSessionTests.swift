import XCTest
@testable import TrapCore

final class RoundSessionTests: XCTestCase {
    private func ready() -> Round {
        var r = Round(id: "r", createdAt: "2026-10-22T07:00:00.000Z", date: "2026-10-22", startTime: "09:30")
        r.place = "Capri"; r.field = 2; r.sky = "sun"; r.temperature = 24; r.humidity = 50
        return r
    }

    func testStartGuardsSetup() {
        var s = RoundSession(round: Round(id: "r", createdAt: "", date: "2026-10-22", startTime: ""))
        XCTAssertEqual(s.phase, .setup)
        XCTAssertThrowsError(try s.start()) { e in
            XCTAssertEqual(e as? RoundSessionError, .missingSetup([.range, .field, .sky, .temperature, .humidity]))
            XCTAssertEqual((e as? RoundSessionError)?.message, "Enter Range, Field, Sky, Temperature, Humidity before you start.")
        }
        XCTAssertThrowsError(try s.record(direction: .left)) { XCTAssertEqual($0 as? RoundSessionError, .notRecording) }
        var ok = RoundSession(round: ready())
        XCTAssertNoThrow(try ok.start())
        XCTAssertEqual(ok.phase, .recording)
        ok.editSetup(); XCTAssertEqual(ok.phase, .setup)
        XCTAssertNoThrow(try ok.start(), "second start has no guard")
    }

    func testEntryAdvancesAndCompletes() throws {
        var s = RoundSession(round: ready()); try s.start()
        XCTAssertEqual(s.index, 0)
        XCTAssertFalse(try s.record(direction: .right))
        XCTAssertEqual(s.index, 0, "direction alone does not advance")
        XCTAssertFalse(try s.record(result: .hitFirst))
        XCTAssertEqual(s.index, 1)
        XCTAssertTrue(s.startStationLocked)
        XCTAssertThrowsError(try s.updateSetup { $0.startStation = 3 }) { XCTAssertEqual($0 as? RoundSessionError, .startStationLocked) }
        XCTAssertNoThrow(try s.updateSetup { $0.place = "Elsewhere" })
        // fill the rest respecting the station rule: the k-th visit to a station gets [R,R,S,L,L][k], k = i / 5
        let pattern: [Direction] = [.right, .right, .straight, .left, .left]
        var completed = false
        for i in 1..<25 { completed = try s.record(direction: pattern[i / 5], result: .lost) }
        XCTAssertTrue(completed); XCTAssertEqual(s.phase, .complete); XCTAssertTrue(s.isComplete)
        s.previous(); XCTAssertEqual(s.phase, .recording); XCTAssertEqual(s.index, 23)
    }

    func testStationQuotaGuard() throws {
        var s = RoundSession(round: ready()); try s.start()
        // targets 0, 5, 10 are all station 1 (start station 1): two rights allowed, the third refused
        try s.record(direction: .right, result: .hitFirst)
        try s.select(target: 5); try s.record(direction: .right, result: .hitFirst)
        try s.select(target: 10)
        XCTAssertThrowsError(try s.record(direction: .right)) { e in
            XCTAssertEqual(e as? RoundSessionError, .directionFull(station: 1, direction: .right))
            XCTAssertNotNil((e as? RoundSessionError)?.recovery)
        }
        XCTAssertNil(s.round.directions[10], "nothing changed on error")
        try s.record(direction: .straight)
        XCTAssertNoThrow(try s.record(direction: .straight), "re-entering the same direction is not a quota violation")
    }

    func testNoTargetAndUndo() throws {
        var s = RoundSession(round: ready()); try s.start()
        try s.record(direction: .left)
        s.recordTiming(at: 0, firstShot: 0.7, secondShot: nil, callLevel: 90, mic: "DJI")
        s.skipTiming(at: 0)
        s.noTarget()
        XCTAssertNil(s.round.directions[0]); XCTAssertNil(s.round.firstShot[0]); XCTAssertEqual(s.round.noTarget[0], 1); XCTAssertFalse(s.skipped.contains(0))
        XCTAssertEqual(try s.undo(), "No target undone. Target 1 is back as it was.")
        XCTAssertEqual(s.round.directions[0], .left); XCTAssertEqual(s.round.firstShot[0], 0.7); XCTAssertEqual(s.round.noTarget[0], 0); XCTAssertTrue(s.skipped.contains(0))
        XCTAssertEqual(try s.undo(), "Target 1 is back in the timing queue.")
        XCTAssertEqual(try s.undo(), "Time removed from target 1.")
        XCTAssertNil(s.round.firstShot[0])
        XCTAssertEqual(try s.undo(), "Target 1 is back as it was.")
        XCTAssertNil(s.round.directions[0])
        XCTAssertThrowsError(try s.undo()) { XCTAssertEqual($0 as? RoundSessionError, .nothingToUndo) }
    }

    func testUndoStackIsBounded() throws {
        var s = RoundSession(round: ready()); try s.start()
        for _ in 0..<80 { s.recordTiming(at: 3, firstShot: 0.6, secondShot: nil, callLevel: nil, mic: "") }
        XCTAssertEqual(s.undoStack.count, RoundSession.undoLimit)
    }

    func testInitFromExistingRound() {
        var r = ready()
        for i in 0..<25 { r.directions[i] = [.right, .right, .straight, .left, .left][i / 5]; r.results[i] = .hitFirst }
        XCTAssertEqual(RoundSession(round: r).phase, .complete)
        r.results[7] = nil
        let s = RoundSession(round: r)
        XCTAssertEqual(s.phase, .recording); XCTAssertEqual(s.index, 7); XCTAssertTrue(s.hasStarted)
    }
}
