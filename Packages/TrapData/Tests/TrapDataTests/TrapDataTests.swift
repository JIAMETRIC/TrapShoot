import XCTest
import SwiftData
import TrapCore
@testable import TrapData

@MainActor
final class TrapDataTests: XCTestCase {
    private func sample(_ n: Int) -> Round {
        var r = Round(id: "r\(n)", createdAt: "2026-10-2\(n)T07:00:00.000Z", date: "2026-10-2\(n)", startTime: "09:00")
        r.directions[0] = .left; r.results[0] = .hitFirst; r.firstShot[0] = 0.7
        r.sessionId = "2026102\(n)-0900-USR"
        return r
    }

    func testInMemoryRepository() throws {
        let repo = InMemoryRoundRepository()
        try repo.save(sample(1)); try repo.save(sample(2))
        XCTAssertEqual(try repo.fetchAll().map(\.id), ["r2", "r1"])
        XCTAssertEqual(try repo.fetch(id: "r1")?.score, 1)
        var r = sample(1); r.results[0] = .lost
        try repo.save(r)
        XCTAssertEqual(try repo.fetch(id: "r1")?.score, 0)
        try repo.delete(id: "r1")
        XCTAssertNil(try repo.fetch(id: "r1"))
        let made = try repo.makeRound(now: Date(), shooter: "Mohammad Tajudeen")
        XCTAssertTrue(made.sessionId.hasSuffix("-MT"))
    }

    func testSwiftDataRepositoryRoundTrip() throws {
        let container = try SwiftDataRoundRepository.container(inMemory: true)
        let repo = SwiftDataRoundRepository(context: container.mainContext)
        let r1 = sample(1), r2 = sample(2)
        try repo.save(r1); try repo.save(r2)
        XCTAssertEqual(try repo.fetchAll().map(\.id), ["r2", "r1"])
        XCTAssertEqual(try repo.fetch(id: "r1"), r1)
        var changed = r1; changed.notes = "edited"; changed.results[1] = .hitSecond
        try repo.save(changed)
        XCTAssertEqual(try repo.fetch(id: "r1"), changed)
        XCTAssertEqual(try repo.sessionIdentifiers().count, 2)
        try repo.delete(id: "r2")
        XCTAssertEqual(try repo.fetchAll().count, 1)
    }

    func testBackupRoundTrip() throws {
        let rounds = [sample(1), sample(2)]
        let data = try Backup.encode(rounds, appVersion: "8.0")
        let back = try Backup.decode(data)
        XCTAssertEqual(back.map(\.id), ["r1", "r2"])
        XCTAssertEqual(back[0], rounds[0])
    }

    func testImporterAcceptsOldShapes() throws {
        let doc = RoundDocument.document(of: sample(3))
        let cache: [String: Any] = ["uid-1": [["id": "r3", "uid": "uid-1", "doc": doc]]]
        let pending: [String: Any] = ["r3": ["id": "r3", "uid": "uid-1", "doc": doc, "at": 1]]
        let table: [Any] = [["id": "r3", "uid": "uid-1", "doc": doc, "created_at": "x"], ["id": "r3", "doc": doc]]
        for shape in [cache, pending] as [Any] {
            let rounds = Importer.rounds(fromJSONObject: shape)
            XCTAssertEqual(rounds.count, 1); XCTAssertEqual(rounds.first?.id, "r3"); XCTAssertEqual(rounds.first?.uid, "")
        }
        XCTAssertEqual(Importer.rounds(fromJSONObject: table).count, 1, "duplicates collapse")
        let repo = InMemoryRoundRepository([sample(3)])
        let result = try Importer.merge(Importer.rounds(fromJSONObject: table) + [sample(4)], into: repo, policy: .skipExisting)
        XCTAssertEqual(result.added, 1); XCTAssertEqual(result.skipped, 1); XCTAssertEqual(repo.count, 2)
    }
}
