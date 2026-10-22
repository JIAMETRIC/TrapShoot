import XCTest
@testable import TrapCore

final class SchemeAndRuleTests: XCTestCase {
    func testSchemesMatchWebApp() throws {
        let fx = try Fixtures.dict("schemes")
        let schemes = try XCTUnwrap(fx["schemes"] as? [String: [[String: Any]]])
        XCTAssertEqual(schemes.count, 10)
        for (k, list) in schemes {
            let scheme = Int(k)!
            XCTAssertEqual(Schemes.table[scheme]?.count, 15)
            for e in list {
                let d = Direction(rawValue: e["d"] as! String)!
                let m = try XCTUnwrap(Schemes.machine(scheme: scheme, station: int(e["stn"])!, direction: d), "scheme \(k) \(e)")
                XCTAssertEqual(m.number, int(e["n"]), "\(k) \(e)")
                XCTAssertEqual(m.side, e["side"] as? String, "\(k) \(e)")
                XCTAssertEqual(m.angle, int(e["angle"]), "\(k) \(e)")
                XCTAssertEqual(m.signedAngle, int(e["signed"]), "\(k) \(e)")
                XCTAssertEqual(m.height, num(e["h"]), "\(k) \(e)")
                XCTAssertEqual(m.label, e["label"] as? String, "\(k) \(e)")
            }
        }
        let quota = try XCTUnwrap(fx["quota"] as? [String: Any])
        for d in Direction.allCases { XCTAssertEqual(d.quota, int(quota[d.rawValue])) }
        XCTAssertEqual(Round.predictionFrom, int(fx["predFrom"]))
        for g in try XCTUnwrap(fx["grades"] as? [[String: Any]]) {
            XCTAssertEqual(Grade.of(num(g["p"])!), int(g["g"]), "grade of \(g)")
        }
    }

    func testRoundRulesMatchWebApp() throws {
        for (ri, fx) in try Fixtures.array("rounds").enumerated() {
            let r = fixtureRound(try XCTUnwrap(fx["round"] as? [String: Any]))
            let tag = "round \(ri) (\(r.id))"
            XCTAssertEqual(r.score, int(fx["score"]), tag)
            XCTAssertEqual(r.recorded, int(fx["recorded"]), tag)
            XCTAssertEqual(r.directionsRecorded, int(fx["dirsRecorded"]), tag)
            let c = try XCTUnwrap(fx["counts"] as? [String: Any])
            XCTAssertEqual(r.counts, ResultCounts(hitFirst: int(c["G"])!, hitSecond: int(c["Y"])!, lost: int(c["R"])!), tag)
            let stations = try XCTUnwrap(fx["stations"] as? [Any]).map { int($0)! }
            XCTAssertEqual((0..<25).map { r.stationIndex(at: $0) }, stations, tag)
            let sc = try XCTUnwrap(fx["stationCounts"] as? [[String: Any]])
            for s in 0..<5 {
                let ours = r.stationCounts(stationIndex: s)
                XCTAssertEqual(ours, DirectionCounts(right: int(sc[s]["R"])!, straight: int(sc[s]["S"])!, left: int(sc[s]["L"])!), "\(tag) station \(s)")
            }
            let over = try XCTUnwrap(fx["stationOver"] as? [Bool])
            XCTAssertEqual((0..<5).map { r.stationOver(stationIndex: $0) }, over, tag)
            let full = try XCTUnwrap(fx["isFull"] as? [[Bool]])
            for i in 0..<25 {
                XCTAssertEqual([r.isFull(at: i, direction: .right), r.isFull(at: i, direction: .straight), r.isFull(at: i, direction: .left)], full[i], "\(tag) isFull \(i)")
            }
            let odds = try XCTUnwrap(fx["odds"] as? [[String: Any]])
            for i in 0..<25 {
                let o = r.directionOdds(at: i)
                XCTAssertEqual(o.right, num(odds[i]["R"])!, accuracy: 1e-12, "\(tag) odds \(i)")
                XCTAssertEqual(o.straight, num(odds[i]["S"])!, accuracy: 1e-12, "\(tag) odds \(i)")
                XCTAssertEqual(o.left, num(odds[i]["L"])!, accuracy: 1e-12, "\(tag) odds \(i)")
            }
            let pr = try XCTUnwrap(fx["predict"] as? [String: Any])
            let p = r.prediction()
            XCTAssertEqual(p.recordedDirections, int(pr["have"]), tag)
            XCTAssertEqual(p.ready, pr["ready"] as? Bool, tag)
            let items = try XCTUnwrap(pr["items"] as? [[String: Any]])
            XCTAssertEqual(p.items.count, items.count, tag)
            for (a, b) in zip(p.items, items) {
                XCTAssertEqual(a.index, int(b["i"]), tag)
                XCTAssertEqual(a.station, int(b["stn"]), tag)
                let bp = b["p"] as! [String: Any]
                XCTAssertEqual(a.odds.right, num(bp["R"])!, accuracy: 1e-12, tag)
                XCTAssertEqual(a.odds.straight, num(bp["S"])!, accuracy: 1e-12, tag)
                XCTAssertEqual(a.odds.left, num(bp["L"])!, accuracy: 1e-12, tag)
                XCTAssertEqual(a.exact?.rawValue, b["exact"] is NSNull ? nil : b["exact"] as? String, tag)
            }
        }
    }

    func testStationOrder() {
        var r = Round(id: "t", createdAt: "", date: "2026-10-22", startTime: "09:00")
        r.startStation = 3
        XCTAssertEqual((0..<6).map { r.station(at: $0) }, [3, 4, 5, 1, 2, 3])
        XCTAssertEqual(r.nextIncomplete(after: 24), 0)
        XCTAssertEqual(r.firstIncomplete, 0)
        XCTAssertFalse(r.hasData)
        r.directions[0] = .left
        XCTAssertTrue(r.hasData)
    }
}
