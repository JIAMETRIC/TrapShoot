import Foundation
import SwiftData

/// Schema versions. Every change to `RoundRecord` adds a new `VersionedSchema` and a stage in the plan,
/// so a shooter's store from any earlier build opens without loss (the "ALTER TABLE" of SwiftData).
public enum TrapSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static var models: [any PersistentModel.Type] { [RoundRecord.self] }
}

public enum TrapMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [TrapSchemaV1.self] }
    /// Add `.lightweight(fromVersion:toVersion:)` for additive changes, `.custom` when data must be rewritten.
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
///   score      INTEGER           -- denormalised from the document for list rows
///   recorded   INTEGER           -- denormalised; 25 = full round
///   document   BLOB              -- the round itself, document v2 JSON (25 targets, times, levels, flags)
/// ```
///
/// Indexes: the primary key only. iOS 17 SwiftData offers no secondary indexes (`#Index` arrives with iOS 18);
/// a lifetime of rounds is a few thousand rows, and the list sort on `createdAt` is a single ordered scan.
/// When the minimum rises to iOS 18, add `#Index<RoundRecord>([\.createdAt], [\.scheme, \.date])`.
///
/// Transactions: SwiftData batches changes in the context until `save()`. `saveMany` turns autosave off,
/// applies every row, saves once, and rolls back the context on any error, so an import is all or nothing.
///
/// Why not 25 `Target` rows per round: every field change would be a migration, every list fetch a join,
/// and nothing in the app queries individual targets across rounds except Analysis, which wants all of them anyway.
/// The document is the aggregate; the columns are the index.
public enum SchemaNotes {}
