import XCTest
@testable import TrapApp

final class TrapAppTests: XCTestCase {
    func testSectionsInTabOrder() {
        XCTAssertEqual(AppSection.allCases.map(\.title), ["Record", "Timer", "Rounds", "Analysis", "Schemes", "Settings"])
    }
}
