import Foundation
import SwiftData
import TrapCore

/// One stored round: a few indexed columns for lists and filters, and the full document v2 JSON as the payload.
/// Keeping the document whole means the on-disk shape is the same as the export and import shape, and a
/// schema change in TrapCore never needs a SwiftData migration for the target arrays.
@Model
public final class RoundRecord {
    @Attribute(.unique) public var id: String
    public var createdAt: String
    public var updatedAt: String
    public var date: String
    public var scheme: Int
    public var type: String
    public var sessionId: String
    public var score: Int
    public var recorded: Int
    public var document: Data

    public init(id: String, createdAt: String, updatedAt: String, date: String, scheme: Int, type: String, sessionId: String, score: Int, recorded: Int, document: Data) {
        self.id = id; self.createdAt = createdAt; self.updatedAt = updatedAt; self.date = date; self.scheme = scheme
        self.type = type; self.sessionId = sessionId; self.score = score; self.recorded = recorded; self.document = document
    }

    public static func make(round r: Round, now: Date = Date()) throws -> RoundRecord {
        RoundRecord(id: r.id, createdAt: r.createdAt, updatedAt: DateText.iso(now), date: r.date, scheme: r.scheme, type: r.type,
                    sessionId: r.sessionId, score: r.score, recorded: r.recorded, document: try RoundDocument.json(of: r, now: now))
    }

    public func update(from r: Round, now: Date = Date()) throws {
        createdAt = r.createdAt; updatedAt = DateText.iso(now); date = r.date; scheme = r.scheme; type = r.type
        sessionId = r.sessionId; score = r.score; recorded = r.recorded
        document = try RoundDocument.json(of: r, now: now)
    }

    public func round() throws -> Round { try RoundDocument.round(id: id, fromJSON: document) }
}

/// The on-device repository.
@MainActor
public final class SwiftDataRoundRepository: RoundRepository {
    public let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    /// The app's container (on disk) or a throwaway one for tests and previews.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let config = ModelConfiguration("TrapShooterPro", schema: Schema(versionedSchema: TrapSchemaV1.self), isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: Schema(versionedSchema: TrapSchemaV1.self), migrationPlan: TrapMigrationPlan.self, configurations: [config])
    }

    public func fetchAll() throws -> [Round] {
        let d = FetchDescriptor<RoundRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return try context.fetch(d).compactMap { try? $0.round() }
    }

    func record(id: String) throws -> RoundRecord? {
        var d = FetchDescriptor<RoundRecord>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    public func fetch(id: String) throws -> Round? { try record(id: id)?.round() }

    public func save(_ round: Round) throws {
        if let existing = try record(id: round.id) {
            try existing.update(from: round)
        } else {
            context.insert(try RoundRecord.make(round: round))
        }
        try context.save()
    }

    public func delete(id: String) throws {
        if let existing = try record(id: id) {
            context.delete(existing)
            try context.save()
        }
    }

    public func sessionIdentifiers() throws -> [(id: String, sessionId: String)] {
        try context.fetch(FetchDescriptor<RoundRecord>()).map { (id: $0.id, sessionId: $0.sessionId) }
    }
}
