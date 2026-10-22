import Foundation
import SwiftData
import TrapCore

/// Schema versions. The native app has not shipped yet, so there is exactly one version and no migration stage.
/// The 7.x hybrid app never had a SwiftData store (its data lived in the web page and Supabase), so there is no
/// older store to migrate. When `RoundRecord` changes after the first TestFlight build, add `TrapSchemaV2` with the
/// new model, keep V1 here unchanged, and add a stage to `TrapMigrationPlan`.
public enum TrapSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [RoundRecord.self] }

    /// One stored round: indexed columns for lists and filters, and the full document v2 JSON as the payload.
    @Model
    public final class RoundRecord {
        @Attribute(.unique) public var id: String
        public var createdAt: String
        public var updatedAt: String
        public var date: String
        public var scheme: Int
        public var type: String
        public var sessionId: String
        /// Range name, for search and grouping without decoding documents.
        public var place: String
        public var score: Int
        public var recorded: Int
        public var document: Data

        public init(id: String, createdAt: String, updatedAt: String, date: String, scheme: Int, type: String, sessionId: String, place: String, score: Int, recorded: Int, document: Data) {
            self.id = id; self.createdAt = createdAt; self.updatedAt = updatedAt; self.date = date; self.scheme = scheme
            self.type = type; self.sessionId = sessionId; self.place = place; self.score = score; self.recorded = recorded; self.document = document
        }

        public static func make(round r: Round, now: Date = Date()) throws -> RoundRecord {
            RoundRecord(id: r.id, createdAt: r.createdAt, updatedAt: DateText.iso(now), date: r.date, scheme: r.scheme, type: r.type,
                        sessionId: r.sessionId, place: r.place, score: r.score, recorded: r.recorded, document: try RoundDocument.json(of: r, now: now))
        }

        public func update(from r: Round, now: Date = Date()) throws {
            createdAt = r.createdAt; updatedAt = DateText.iso(now); date = r.date; scheme = r.scheme; type = r.type
            sessionId = r.sessionId; place = r.place; score = r.score; recorded = r.recorded
            document = try RoundDocument.json(of: r, now: now)
        }

        public func round() throws -> Round { try RoundDocument.round(id: id, fromJSON: document) }
    }
}

/// The current record type. Code outside this file never names a version.
public typealias RoundRecord = TrapSchemaV1.RoundRecord
public typealias CurrentSchema = TrapSchemaV1

public enum TrapMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [TrapSchemaV1.self] }
    /// Empty until a V2 exists. Then: `.lightweight(fromVersion: TrapSchemaV1.self, toVersion: TrapSchemaV2.self)`.
    public static var stages: [MigrationStage] { [] }
}

/// Schema design in one place, for the reader who thinks in tables:
///
/// ```
/// TABLE RoundRecord
///   id         TEXT PRIMARY KEY  -- @Attribute(.unique); the web app's "r…" ids are kept so imports are idempotent
///   createdAt  TEXT              -- ISO‑8601 UTC; sorts lexicographically = chronologically; list order
///   updatedAt  TEXT
///   date       TEXT              -- yyyy-MM-dd local; filters and section headers
///   scheme     INTEGER           -- 1…10; filter for Analysis
///   type       TEXT              -- Training / Competition
///   sessionId  TEXT              -- human id; uniqueness enforced in code (SessionID), not by the store
///   place      TEXT              -- range name for search and grouping
///   score      INTEGER           -- denormalised from the document for list rows
///   recorded   INTEGER           -- denormalised; 25 = full round
///   document   BLOB              -- the round itself, document v2 JSON (25 targets, times, levels, flags)
/// ```
///
/// Store: `AppConstants.storeName` + ".store" in Application Support (the same constant `TrapPlatform.AppPaths` uses).
///
/// Indexes: the primary key only. iOS 17 SwiftData offers no secondary indexes (`#Index` arrives with iOS 18);
/// a lifetime of rounds is a few thousand rows, and the list sort on `createdAt` is a single ordered scan.
///
/// Transactions: SwiftData batches changes in the context until `save()`. `saveMany` turns autosave off,
/// applies every row, saves once, and rolls back the context on any error, so an import is all or nothing.
///
/// Why not 25 `Target` rows per round: every field change would be a migration, every list fetch a join,
/// and nothing in the app queries individual targets across rounds except Analysis, which wants all of them anyway.
/// The document is the aggregate; the columns are the index.
public enum SchemaNotes {}
