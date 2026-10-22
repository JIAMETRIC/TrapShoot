import Foundation
import SwiftData
import TrapCore

// `RoundRecord` and the schema versions live in Schema.swift.

/// The on-device repository.
@MainActor
public final class SwiftDataRoundRepository: RoundRepository {
    public let context: ModelContext

    public init(context: ModelContext) { self.context = context }

    /// The app's container (on disk) or a throwaway one for tests and previews.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: CurrentSchema.self)
        let config = ModelConfiguration(AppConstants.storeName, schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, migrationPlan: TrapMigrationPlan.self, configurations: [config])
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

    /// Column fetch only: never loads the document payloads.
    public func sessionIdentifiers() throws -> [(id: String, sessionId: String)] {
        var d = FetchDescriptor<RoundRecord>()
        d.propertiesToFetch = [\.id, \.sessionId]
        return try context.fetch(d).map { (id: $0.id, sessionId: $0.sessionId) }
    }
}
