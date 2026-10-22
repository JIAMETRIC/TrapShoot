import XCTest
@testable import TrapCore

final class TrapAnalysisTests: XCTestCase {
    func testTrapAnalysisMatchesWebApp() throws {
        for set in try Fixtures.array("analysis") {
            let name = set["name"] as! String
            let list = try XCTUnwrap(set["rounds"] as? [[String: Any]]).map(fixtureRound)
            // scheme counts and dominant scheme
            let counts = try XCTUnwrap(set["schemeCounts"] as? [String: Any])
            XCTAssertEqual(Analysis.schemeCounts(list), Dictionary(uniqueKeysWithValues: counts.map { (Int($0.key)!, int($0.value)!) }), name)
            let dominant = set["dominant"] is NSNull ? nil : int(set["dominant"])
            XCTAssertEqual(Analysis.dominantScheme(list), dominant, name)
            // overview
            let ov = try XCTUnwrap(set["overview"] as? [String: Any])
            let o = Analysis.overview(list)
            XCTAssertEqual(o.rounds, int(ov["rounds"]), name)
            XCTAssertEqual(o.fullRounds, int(ov["fullRounds"]), name)
            XCTAssertEqual(o.averageScore == nil ? nil : o.averageScoreText, ov["avgScore"] is NSNull ? nil : ov["avgScore"] as? String, name)
            XCTAssertEqual(o.bestScore, ov["best"] is NSNull ? nil : int(ov["best"]), name)
            XCTAssertEqual(o.hitRateText, ov["hitRate"] as? String, name)
            XCTAssertEqual(o.firstBarrelText, ov["firstBarrel"] as? String, name)
            XCTAssertEqual(o.secondBarrelText, ov["secondBarrel"] as? String, name)
            // trend
            let trend = try XCTUnwrap(set["trend"] as? [[String: Any]])
            let t = Analysis.trend(list)
            XCTAssertEqual(t.map(\.roundID), trend.map { $0["id"] as! String }, name)
            XCTAssertEqual(t.map(\.score), trend.map { int($0["score"])! }, name)
            XCTAssertEqual(t.map(\.date), trend.map { $0["date"] as! String }, name)
            // trap analysis
            guard let scheme = dominant else { XCTAssertTrue(set["trapStats"] is NSNull, name); continue }
            let ts = try XCTUnwrap(set["trapStats"] as? [String: Any])
            let a = Analysis.trapAnalysis(list, scheme: scheme)
            XCTAssertEqual(a.rounds, int(ts["rounds"]), name)
            XCTAssertEqual(a.skipped, int(ts["skipped"]), name)
            XCTAssertEqual(a.timed, int(ts["timed"]), name)
            XCTAssertEqual(a.outliers, int(ts["outl"]), name)
            assertOptional(a.averageTime, optDouble(ts["avgT"]), name + " avgT")
            let tot = ts["tot"] as! [String: Any]
            XCTAssertEqual([a.totals.shots, a.totals.hitFirst, a.totals.hitSecond, a.totals.lost], [int(tot["shots"])!, int(tot["g"])!, int(tot["y"])!, int(tot["r"])!], name)
            for (b, k) in [(a.early, "early"), (a.late, "late")] {
                let e = ts[k] as! [String: Any]
                XCTAssertEqual([b.targets, b.hits], [int(e["n"])!, int(e["hit"])!], name + " " + k)
            }
            let st = ts["stations"] as! [[String: Any]]
            for (s, e) in zip(a.stations, st) {
                XCTAssertEqual([s.station, s.shots, s.hitFirst, s.hitSecond, s.lost], [int(e["stn"])!, int(e["shots"])!, int(e["g"])!, int(e["y"])!, int(e["r"])!], name)
            }
            if ts["fit"] is NSNull { XCTAssertNil(a.fit, name) } else {
                let f = ts["fit"] as! [String: Any], fit = try XCTUnwrap(a.fit, name)
                XCTAssertEqual(fit.b0, num(f["b0"])!, accuracy: 1e-9, name)
                XCTAssertEqual(fit.b1, num(f["b1"])!, accuracy: 1e-9, name)
                XCTAssertEqual(fit.b2, num(f["b2"])!, accuracy: 1e-9, name)
                XCTAssertEqual(fit.r2, num(f["r2"])!, accuracy: 1e-9, name)
            }
            let traps = ts["traps"] as! [[String: Any]]
            XCTAssertEqual(a.traps.count, traps.count, name)
            for (x, y) in zip(a.traps, traps) {
                let tag = "\(name) trap \(x.number)"
                XCTAssertEqual([x.number, x.station, x.angle, x.shots, x.hitFirst, x.hitSecond, x.lost], [int(y["n"])!, int(y["stn"])!, int(y["angle"])!, int(y["shots"])!, int(y["g"])!, int(y["y"])!, int(y["r"])!], tag)
                XCTAssertEqual(x.label, y["label"] as? String, tag)
                XCTAssertEqual(x.height, num(y["h"])!, tag)
                XCTAssertEqual(x.times, (y["times"] as! [Any]).map { num($0)! }, tag)
                assertOptional(x.averageTime, optDouble(y["avg"]), tag + " avg")
                assertOptional(x.versusFit, optDouble(y["vs"]), tag + " vs", accuracy: 1e-7)
            }
            let dev = ts["dev"] as! [[String: Any]]
            for (x, y) in zip(a.deviations, dev) {
                XCTAssertEqual(x.key, y["k"] as? String, name)
                XCTAssertEqual([x.targets, x.misses], [int(y["n"])!, int(y["miss"])!], name + " " + x.key)
            }
            // findings, word for word
            let findings = try XCTUnwrap(set["findings"] as? [String])
            XCTAssertEqual(Analysis.findings(a), findings, name)
        }
    }

    func testSolve3AndHelpers() {
        let x = Analysis.solve3([[2, 1, -1], [-3, -1, 2], [-2, 1, 2]], [8, -11, -3])!
        XCTAssertEqual(x[0], 2, accuracy: 1e-12); XCTAssertEqual(x[1], 3, accuracy: 1e-12); XCTAssertEqual(x[2], -1, accuracy: 1e-12)
        XCTAssertNil(Analysis.solve3([[1, 2, 3], [2, 4, 6], [1, 1, 1]], [1, 2, 3]))
        XCTAssertEqual(Analysis.signedMs(12.4), "+12 ms")
        XCTAssertEqual(Analysis.signedMs(-7.6), "−8 ms")
        XCTAssertEqual(Analysis.signedMs(0), "0 ms")
        XCTAssertEqual(Analysis.signedMs(nil), "–")
        XCTAssertEqual(Analysis.heightLabel(1.75), "1.75 m")
        XCTAssertEqual(Analysis.heightLabel(2), "2 m")
        XCTAssertEqual(Analysis.jsRound(2.5), 3)
        XCTAssertEqual(Analysis.jsRound(-2.5), -2)
    }

    /// Reference values from node: `(81.25).toFixed(1)` and so on.
    func testFixedMatchesJavaScriptToFixed() {
        let cases: [(Double, Int, String)] = [
            (81.25, 1, "81.3"), (1.005, 2, "1.00"), (2.5, 0, "3"), (-2.5, 0, "-3"), (0.125, 2, "0.13"),
            (-0.04, 1, "-0.0"), (0, 1, "0.0"), (99.95, 1, "100.0"), (-45.5, 0, "-46")
        ]
        for (v, d, js) in cases { XCTAssertEqual(JSText.fixed(v, d), js, "\(v).toFixed(\(d))") }
        XCTAssertEqual(Analysis.percent(13, 16), "81.3%")
    }
}

func assertOptional(_ a: Double?, _ b: Double?, _ message: String, accuracy: Double = 1e-9, file: StaticString = #filePath, line: UInt = #line) {
    switch (a, b) {
    case let (x?, y?): XCTAssertEqual(x, y, accuracy: accuracy, message, file: file, line: line)
    default: XCTAssertEqual(a, b, message, file: file, line: line)
    }
}
