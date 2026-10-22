import XCTest
import TrapCore
@testable import TrapApp

final class TrapAppTests: XCTestCase {
    func testSectionsInTabOrder() {
        XCTAssertEqual(AppSection.allCases.map(\.title), ["Record", "Timer", "Rounds", "Analysis", "Schemes", "Settings"])
    }
}

@MainActor
final class DemoModeTests: XCTestCase {
    func testSampleRoundsObeyTheRules() {
        let rounds = DemoMode.sampleRounds()
        XCTAssertEqual(rounds.count, 15)
        for r in rounds { XCTAssertEqual(Validation.issues(in: r), [], r.id) }
        XCTAssertEqual(rounds.filter(\.isComplete).count, 14)
        XCTAssertEqual(rounds.last?.recorded, 12, "one round in progress")
        XCTAssertEqual(DemoMode.sampleRounds().map(\.score), rounds.map(\.score), "the same rounds every run")
    }

    func testDemoAppOpensTheRoundInProgress() {
        let app = DemoMode.makeApp()
        XCTAssertEqual(app.record.round.id, "demo14")
        XCTAssertEqual(app.record.session.index, 12)
        XCTAssertEqual(app.record.session.phase, .recording)
    }
}
