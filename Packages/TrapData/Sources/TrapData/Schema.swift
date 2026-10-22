import Foundation
import SwiftData
import TrapCore

/// Schema versions. Every change to `RoundRecord` adds a new `VersionedSchema` and a stage in the plan,
/// so a shooter's store from any earlier build opens without loss (the "ALTER TABLE" of SwiftData).
public enum TrapSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [RoundRecord.self] }

    /// First shape of the store (build 8). Kept so stores from that build can migrate.
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
    }
}

public enum TrapSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static var models: [any PersistentModel.Type] { [RoundRecord.self] }

    /// V2 adds `place` as a column so the Rounds list can search and group by range without decoding documents.
    /// A lightweight migration adds it with an empty default; `SwiftDataRoundRepository.backfill()` fills it once.
    @Model
    public final class RoundRecord {
        @Attribute(.unique) public var id: String
        public var createdAt: String
        public var updatedAt: String
        public var date: String
        public var scheme: Int
        public var type: String
        public var sessionId: String
        public var place: String = ""
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
public typealias RoundRecord = TrapSchemaV2.RoundRecord
public typealias CurrentSchema = TrapSchemaV2

public enum TrapMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [TrapSchemaV1.self, TrapSchemaV2.self] }
    public static var stages: [MigrationStage] { [v1ToV2] }
    /// Additive: one new column with a default. No data rewrite; `backfill()` fills `place` from the documents.
    static let v1ToV2 = MigrationStage.lightweight(fromVersion: TrapSchemaV1.self, toVersion: TrapSchemaV2.self)
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
///   place      TEXT              -- V2; range name for search and grouping
///   score      INTEGER           -- denormalised from the document for list rows
///   recorded   INTEGER           -- denormalised; 25 = full round
///   document   BLOB              -- the round itself, document v2 JSON (25 targets, times, levels, flags)
/// ```
///
/// Indexes: the primary key only. iOS 17 SwiftData offers no secondary indexes (`#Index` arrives with iOS 18);
/// a lifetime of rounds is a few thousand rows, and the list sort on `createdAt` is a single ordered scan.
/// When the minimum rises to iOS 18, add `#Index<RoundRecord>([\.createdAt], [\.scheme, \.date])`.
///
/// Migrations: V1 (build 8) → V2 (adds `place`, lightweight). Each new version is a new enum; the old ones stay.
///
/// Transactions: SwiftData batches changes in the context until `save()`. `saveMany` turns autosave off,
/// applies every row, saves once, and rolls back the context on any error, so an import is all or nothing.
///
/// Why not 25 `Target` rows per round: every field change would be a migration, every list fetch a join,
/// and nothing in the app queries individual targets across rounds except Analysis, which wants all of them anyway.
/// The document is the aggregate; the columns are the index.
public enum SchemaNotes {}
