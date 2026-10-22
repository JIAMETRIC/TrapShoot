import XCTest
@testable import TrapCore

final class DocumentAndExportTests: XCTestCase {
    func testDocumentRoundTripMatchesWebApp() throws {
        for (ri, fx) in try Fixtures.array("rounds").enumerated() {
            let src = try XCTUnwrap(fx["round"] as? [String: Any])
            let r = fixtureRound(src)
            let theirs = try XCTUnwrap(fx["doc"] as? [String: Any])
            assertDocument(RoundDocument.document(of: r), matches: theirs)
            // and back again through JSON
            let data = try RoundDocument.json(of: r)
            let again = try RoundDocument.round(id: r.id, fromJSON: data)
            XCTAssertEqual(again, r, "round \(ri) JSON round trip")
        }
    }

    func testTolerantImportMatchesNorm() throws {
        for c in try Fixtures.array("norm") {
            let id = c["id"] as! String
            let r = RoundDocument.round(id: id, from: c["doc"] as! [String: Any])
            XCTAssertEqual(r.id, id)
            let out = try XCTUnwrap(c["out"] as? [String: Any])
            // out is the JavaScript round object; it carries the same keys as the document plus id, minus v/updatedAt
            assertDocument(RoundDocument.document(of: r), matches: out, ignoring: ["updatedAt", "v"])
            XCTAssertEqual(r.appVersion, out["ver"] as? String, id)
        }
    }

    func testBreakDistanceMatchesWebApp() throws {
        let fx = try Fixtures.dict("break")
        let tables = try XCTUnwrap(fx["shotTime"] as? [String: [String: Any]])
        var models: [Int: BreakDistanceModel] = [:]
        for (si, t) in tables {
            let st = t["settings"] as! [String: Any]
            var s = BreakSettings()
            s.releaseDelayMs = num(st["delay"])!; s.claySpeed = num(st["v"])!; s.shotSpeed = num(st["vs"])!
            s.shotSize = ShotSize(rawValue: st["size"] as! String)!
            let m = BreakDistanceModel(settings: s)
            models[Int(si)!] = m
            for a in t["at"] as! [[String: Any]] {
                XCTAssertEqual(m.shotTime(num(a["x"])!), num(a["t"])!, accuracy: 1e-12, "settings \(si) shotTime(\(a["x"]!))")
            }
        }
        for d in try XCTUnwrap(fx["distance"] as? [[String: Any]]) {
            let m = models[int(d["si"])!]!
            let ours = m.distance(scheme: int(d["scheme"])!, station: int(d["stn"])!, direction: Direction(rawValue: d["d"] as! String)!, timeSec: optDouble(d["t"]))
            let theirs = optDouble(d["m"])
            if let a = ours, let b = theirs { XCTAssertEqual(a, b, accuracy: 1e-9, "\(d)") } else { XCTAssertEqual(ours, theirs, "\(d)") }
        }
        // the README example: scheme 2, station 3, straight, 1st shot 0.704 s
        XCTAssertNotNil(BreakDistanceModel().distance(scheme: 2, station: 3, direction: .straight, timeSec: 0.704))
    }

    func testBreakPerTargetAndCSVMatchWebApp() throws {
        let model = BreakDistanceModel()
        for (ri, fx) in try Fixtures.array("rounds").enumerated() {
            let r = fixtureRound(try XCTUnwrap(fx["round"] as? [String: Any]))
            let shots = try XCTUnwrap(fx["brkShot"] as? [Any]).map { int($0)! }
            XCTAssertEqual((0..<25).map { r.breakShot(at: $0) }, shots, "round \(ri)")
            let brk = try XCTUnwrap(fx["brk"] as? [Any])
            for i in 0..<25 {
                let ours = r.breakDistance(at: i, model: model), theirs = optDouble(brk[i])
                if let a = ours, let b = theirs { XCTAssertEqual(a, b, accuracy: 1e-9, "round \(ri) target \(i)") } else { XCTAssertEqual(ours, theirs, "round \(ri) target \(i)") }
            }
            let csv = CSVExport.csv(rounds: [r], breakModel: model)
            let theirs = fx["csv"] as! String
            let a = csv.split(separator: "\n", omittingEmptySubsequences: false), b = theirs.split(separator: "\n", omittingEmptySubsequences: false)
            XCTAssertEqual(a.count, b.count, "round \(ri) csv line count")
            for (n, (x, y)) in zip(a, b).enumerated() where x != y {
                XCTFail("round \(ri) csv line \(n)\n ours:   \(x)\n theirs: \(y)")
            }
        }
    }

    func testAnalysisMatchesWebApp() throws {
        for (ri, fx) in try Fixtures.array("rounds").enumerated() {
            let r = fixtureRound(try XCTUnwrap(fx["round"] as? [String: Any]))
            let st = try XCTUnwrap(fx["stats"] as? [String: Any])
            XCTAssertEqual(Analysis.stats([r]), RoundStats(rounds: int(st["rounds"])!, targets: int(st["n"])!, hits: int(st["hit"])!, firstShotHits: int(st["g"])!), "round \(ri)")
            let theirs = try XCTUnwrap(fx["analyse"] as? [[String: Any]])
            let ours = Analysis.tables([r])
            XCTAssertEqual(ours.map(\.title), theirs.map { $0["t"] as! String }, "round \(ri) dimensions")
            for (a, b) in zip(ours, theirs) {
                let rows = b["rows"] as! [[String: Any]]
                XCTAssertEqual(a.rows.count, rows.count, "round \(ri) \(a.title)")
                for (x, y) in zip(a.rows, rows) {
                    XCTAssertEqual(x.key, y["k"] as? String, "round \(ri) \(a.title)")
                    XCTAssertEqual(x.targets, int(y["n"]), "round \(ri) \(a.title) \(x.key)")
                    XCTAssertEqual(x.hits, int(y["hit"]), "round \(ri) \(a.title) \(x.key)")
                    XCTAssertEqual(x.firstShotHits, int(y["g"]), "round \(ri) \(a.title) \(x.key)")
                }
            }
        }
    }

    func testSessionIdsMatchWebApp() throws {
        let fx = try Fixtures.dict("sessions")
        for c in try XCTUnwrap(fx["initials"] as? [[String: Any]]) {
            XCTAssertEqual(SessionID.initials(c["name"] as! String), c["out"] as? String, "initials of '\(c["name"]!)'")
        }
        let existing = [(id: "x1", sessionId: "20261022-0930-MT"), (id: "x2", sessionId: "20261022-0930-MT-2")]
        for c in try XCTUnwrap(fx["genSid"] as? [[String: Any]]) {
            let s = c["r"] as! [String: Any]
            var r = Round(id: s["id"] as! String, createdAt: "", date: s["date"] as! String, startTime: s["startTime"] as! String)
            r.shooter = s["shooter"] as! String
            XCTAssertEqual(SessionID.make(for: r, existing: existing), c["out"] as? String, "\(s)")
        }
    }

    func testJavaScriptNumberText() {
        XCTAssertEqual(JSText.number(2), "2")
        XCTAssertEqual(JSText.number(2.5), "2.5")
        XCTAssertEqual(JSText.number(0.704), "0.704")
        XCTAssertEqual(JSText.number(-20), "-20")
        XCTAssertEqual(JSText.number(1.75), "1.75")
        XCTAssertEqual(JSText.number(1e-7), "1e-7")
        XCTAssertEqual(CSVExport.cell("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.cell("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.cell(nil), "")
    }

    func testNewRoundHasWebAppShapes() {
        let r = Round.new()
        XCTAssertTrue(r.id.hasPrefix("r"))
        XCTAssertEqual(r.date.count, 10)
        XCTAssertEqual(r.startTime.count, 5)
        XCTAssertEqual(r.createdAt.count, 24)
        XCTAssertTrue(r.createdAt.hasSuffix("Z"))
        XCTAssertEqual(r.directions.count, 25)
        XCTAssertEqual(r.scheme, 2)
    }
}
