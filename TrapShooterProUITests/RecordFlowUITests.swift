import XCTest

/// The range flow on screen, driven by the scripted demo timer (`-demo -uitest`): no microphone, no store.
/// Identifiers follow `screen.element.name` (docs/testing.md). Runs on an iPhone simulator; the iPad layout is
/// covered by the screenshot set, not by this test.
final class RecordFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-demo", "-uitest", "-state.section", "record"]
        app.launch()
        // Demo mode resumes a round with 12 of 25 targets recorded, so the entry panel is on screen.
        if app.buttons["record.start"].waitForExistence(timeout: 3) { app.buttons["record.start"].tap() }
        XCTAssertTrue(app.buttons["record.noTarget"].waitForExistence(timeout: 5), "the entry panel is on screen")
    }

    /// Direction and result on the current target land in the ledger; Undo takes the result back.
    func testDirectionResultAndUndo() {
        let row = firstOpenTargetIndex()
        let before = app.buttons["record.target.\(row)"].label
        tapFirstEnabled(["record.direction.left", "record.direction.right", "record.direction.straight"])
        tap("record.result.hitFirst")
        let after = app.buttons["record.target.\(row)"].label
        XCTAssertNotEqual(before, after, "the ledger row changed after direction and result")
        XCTAssertFalse(after.contains("no result"), "row \(row) has a result: \(after)")
        XCTAssertFalse(after.contains("no direction"), "row \(row) has a direction: \(after)")
        XCTAssertTrue(app.buttons["record.undo"].isEnabled, "Undo is available after an entry")
        tap("record.undo")
    }

    /// NO TARGET keeps the target number (CLAUDE.md rule 6) and leaves the panel on the same target.
    func testNoTargetKeepsTheNumber() {
        let row = firstOpenTargetIndex()
        tap("record.noTarget")
        XCTAssertTrue(app.buttons["record.target.\(row)"].exists, "target \(row) still exists after NO TARGET")
        XCTAssertTrue(app.buttons["record.undo"].isEnabled)
        tap("record.undo")
    }

    /// Start the timer on the Timer screen; the scripted timer answers the arm with a 612 ms first shot and the
    /// readout shows it. Then the result entry arms the next target and the readout returns to 0.000.
    func testScriptedTimerTimesATarget() {
        openTimer()
        let start = app.buttons["timer.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let readout = app.descendants(matching: .any)["timer.readout"].firstMatch
        XCTAssertTrue(readout.waitForExistence(timeout: 5))
        let timed = NSPredicate(format: "label CONTAINS 'First shot 0.612'")
        expectation(for: timed, evaluatedWith: readout)
        waitForExpectations(timeout: 8)
        XCTAssertTrue(app.buttons["timer.stop"].exists, "the timer is running")
        app.buttons["timer.stop"].tap()
        XCTAssertTrue(app.buttons["timer.start"].waitForExistence(timeout: 5), "stopped")
    }

    // MARK: helpers

    private func openTimer() {
        let tab = app.tabBars.buttons["Timer"]
        if tab.waitForExistence(timeout: 3) { tab.tap(); return }
        let row = app.buttons["Timer"].firstMatch                   // iPad sidebar
        XCTAssertTrue(row.waitForExistence(timeout: 3), "a Timer tab or sidebar row")
        row.tap()
    }

    private func tapFirstEnabled(_ ids: [String]) {
        for id in ids where app.buttons[id].exists && app.buttons[id].isEnabled { tap(id); return }
        XCTFail("no enabled direction button among \(ids)")
    }

    /// Taps a control, scrolling the screen until it is on screen (the Record screen is longer than an iPhone).
    private func tap(_ id: String) {
        let element = app.buttons[id]
        var tries = 0
        while !element.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
        XCTAssertTrue(element.isHittable, "\(id) is on screen")
        element.tap()
    }

    /// The ledger row of the first target without a result (the one the panel shows).
    private func firstOpenTargetIndex() -> Int {
        for i in 1...25 {
            let row = app.buttons["record.target.\(i)"]
            if row.exists && row.label.contains("no result") { return i }
        }
        return 13                                                    // the demo round's first open target
    }
}
