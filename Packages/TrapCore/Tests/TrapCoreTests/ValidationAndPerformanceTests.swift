import XCTest
@testable import TrapCore

final class ValidationAndPerformanceTests: XCTestCase {
    private func clean() -> Round {
        var r = Round(id: "r", createdAt: "2026-10-22T07:00:00.000Z", date: "2026-10-22", startTime: "09:30")
        r.directions[0] = .left; r.results[0] = .hitFirst; r.firstShot[0] = 0.7
        return r
    }

    func testCleanRoundHasNoIssues() {
        XCTAssertEqual(Validation.issues(in: clean()), [])
    }

    func testIssuesAreFound() {
        var r = clean()
        r.date = "22/10/2026"; r.startTime = "9:30"; r.startStation = 7; r.scheme = 11; r.session = 0
        r.notes = String(repeating: "x", count: 2001); r.temperature = 80; r.humidity = -1
        r.firstShot[1] = 9; r.firstShot[2] = 0.8; r.secondShot[2] = 0.5
        r.directions[0] = .right; r.directions[5] = .right; r.directions[10] = .right   // station 1 three rights
        let issues = Validation.issues(in: r)
        XCTAssertTrue(issues.contains(.badDate("22/10/2026")))
        XCTAssertTrue(issues.contains(.badStartTime("9:30")))
        XCTAssertTrue(issues.contains(.badStartStation(7)))
        XCTAssertTrue(issues.contains(.badScheme(11)))
        XCTAssertTrue(issues.contains(.badSession(0)))
        XCTAssertTrue(issues.contains(.textTooLong(field: "Notes", limit: 2000)))
        XCTAssertTrue(issues.contains(.temperatureOutOfRange(80)))
        XCTAssertTrue(issues.contains(.humidityOutOfRange(-1)))
        XCTAssertTrue(issues.contains(.shotTimeOutOfRange(target: 1, seconds: 9)))
        XCTAssertTrue(issues.contains(.secondBeforeFirst(target: 2)))
        XCTAssertTrue(issues.contains(.stationOverQuota(station: 1)))
        XCTAssertFalse(issues[0].message.isEmpty)
    }

    func testSanitizedFixesWhatItCan() {
        var r = clean()
        r.place = "  Capri Range \n"; r.notes = String(repeating: "n", count: 2500); r.temperature = 99; r.humidity = .nan
        r.firstShot[1] = 9; r.firstShot[2] = 0.8; r.secondShot[2] = 0.5; r.session = 0; r.field = 0; r.noTarget[3] = -4
        let s = Validation.sanitized(r)
        XCTAssertEqual(s.place, "Capri Range")
        XCTAssertEqual(s.notes.count, 2000)
        XCTAssertEqual(s.temperature, 60); XCTAssertNil(s.humidity)
        XCTAssertNil(s.firstShot[1]); XCTAssertEqual(s.firstShot[2], 0.8); XCTAssertNil(s.secondShot[2])
        XCTAssertEqual(s.session, 1); XCTAssertNil(s.field); XCTAssertEqual(s.noTarget[3], 0)
        XCTAssertEqual(Validation.issues(in: s).filter { if case .textTooLong = $0 { return true }; return false }, [])
    }

    func testCSVFormulaInjectionIsNeutralised() {
        XCTAssertEqual(CSVExport.cell("=HYPERLINK(\"x\")"), "\"'=HYPERLINK(\"\"x\"\")\"", "prefixed, then quoted because of the quotes")
        XCTAssertEqual(CSVExport.cell("+1"), "'+1")
        XCTAssertEqual(CSVExport.cell("-note"), "'-note")
        XCTAssertEqual(CSVExport.cell("@me"), "'@me")
        XCTAssertEqual(CSVExport.cell(-20), "-20", "numbers are untouched")
        XCTAssertEqual(CSVExport.cell(-0.5), "-0.5")
        XCTAssertEqual(CSVExport.cell("plain"), "plain")
    }

    func testDisplayError() {
        XCTAssertEqual(DisplayError(any: ValidationIssue.badScheme(0)).message, "Scheme 0 does not exist; schemes run 1 to 10.")
        XCTAssertEqual(DisplayError(any: NSError(domain: "x", code: 1)).message, "Something went wrong.")
        XCTAssertEqual(DisplayError("A", recovery: "B").text, "A B")
    }

    // MARK: performance budgets (see docs/performance.md)

    private func manyRounds(_ n: Int) -> [Round] {
        (0..<n).map { k in
            var r = Round(id: "r\(k)", createdAt: String(format: "2026-%02d-%02dT07:00:00.000Z", 1 + k % 12, 1 + k % 28), date: String(format: "2026-%02d-%02d", 1 + k % 12, 1 + k % 28), startTime: "09:00")
            r.scheme = 1 + k % 10; r.startStation = 1 + k % 5
            for i in 0..<25 {
                r.directions[i] = Direction.allCases[(i + k) % 3]
                r.results[i] = TargetResult.allCases[(i * 7 + k) % 3]
                r.firstShot[i] = 0.6 + Double((i * 13 + k) % 30) / 100
                if i % 3 == 0 { r.secondShot[i] = r.firstShot[i]! + 0.3 }
            }
            return r
        }
    }

    func testAnalysisOfAThousandRoundsIsFast() {
        let rounds = manyRounds(1000)
        measure {                                   // budget: well under 0.5 s on a phone
            _ = Analysis.tables(rounds)
            _ = Analysis.trapAnalysis(rounds, scheme: 2)
            _ = Analysis.overview(rounds)
        }
    }

    func testCSVOfAThousandRoundsIsFast() {
        let rounds = manyRounds(1000), model = BreakDistanceModel()
        measure { _ = CSVExport.csv(rounds: rounds, breakModel: model) }   // 25,000 rows
    }

    func testDocumentRoundTripIsFast() throws {
        let rounds = manyRounds(200)
        measure {
            for r in rounds { _ = try? RoundDocument.round(id: r.id, fromJSON: try! RoundDocument.json(of: r)) }
        }
    }
}
