import Foundation
import TrapCore

/// Full-library backup: every round as its document v2, in one JSON file the shooter keeps in Files or iCloud Drive.
public enum Backup {
    public static let format = "trapshooterpro-backup"
    public static let version = 1
    public static let fileExtension = "trapbackup.json"

    public static func encode(_ rounds: [Round], now: Date = Date(), appVersion: String) throws -> Data {
        let body: [String: Any] = [
            "app": "TrapShooterPro", "format": format, "v": version, "appVersion": appVersion,
            "exported": DateText.iso(now), "count": rounds.count,
            "rounds": rounds.map { ["id": $0.id, "doc": RoundDocument.document(of: $0, now: now)] }
        ]
        return try RoundDocument.jsonData(body, options: [.prettyPrinted, .sortedKeys])
    }

    /// Reads a backup, a plain list of rows, or the 7.x browser cache. Unknown rows are skipped, never fatal.
    public static func decode(_ data: Data) throws -> [Round] {
        let any = try JSONSerialization.jsonObject(with: data)
        return Importer.rounds(fromJSONObject: any)
    }
}

/// Accepts every shape the old app ever produced:
/// - this app's backup `{ "format": "trapshooterpro-backup", "rounds": [ { id, doc } ] }`
/// - a Supabase export of the `rounds` table: `[ { id, uid, doc, ... } ]`
/// - the 7.x browser cache `trap-shooter-pro-rounds-cache-v7`: `{ "<uid>": [ { id, uid, doc } ] }`
/// - the 7.x pending queue: `{ "<id>": { id, uid, doc, at } }`
/// - a single document, or a list of documents, with an `id` field
public enum Importer {
    public static func rounds(fromJSONObject any: Any) -> [Round] {
        var out: [Round] = []
        func take(row: [String: Any]) {
            if let id = row["id"] as? String, let doc = row["doc"] as? [String: Any] {
                var r = RoundDocument.round(id: id, from: doc)
                r.uid = ""                                  // no accounts in this app
                out.append(r)
            } else if let id = row["id"] as? String, row["dirs"] != nil || row["res"] != nil || row["date"] != nil {
                var r = RoundDocument.round(id: id, from: row)
                r.uid = ""
                out.append(r)
            }
        }
        func walk(_ v: Any) {
            if let list = v as? [Any] { list.forEach(walk); return }
            guard let dict = v as? [String: Any] else { return }
            if let rows = dict["rounds"] as? [Any] { rows.forEach(walk); return }
            if dict["id"] != nil { take(row: dict); return }
            for (_, value) in dict { walk(value) }      // cache and pending shapes: values are rows or lists of rows
        }
        walk(any)
        var seen = Set<String>()
        return out.filter { seen.insert($0.id).inserted }
    }

    /// Merge policy when importing into an existing library.
    public enum Policy: Sendable { case skipExisting, replaceExisting }

    /// Rounds are sanitised on the way in; structural problems are reported, not fatal. The write is one transaction.
    @MainActor
    public static func merge(_ rounds: [Round], into repo: RoundRepository, policy: Policy) throws -> ImportReport {
        var report = ImportReport()
        var toWrite: [Round] = []
        let existing = Set(try repo.sessionIdentifiers().map(\.id))      // ids only, no document decoding
        for raw in rounds {
            let r = Validation.sanitized(raw)
            let issues = Validation.issues(in: r)
            if !issues.isEmpty { report.issues[r.id] = issues }
            if existing.contains(r.id) {
                if policy == .replaceExisting { toWrite.append(r); report.replaced += 1 } else { report.skipped += 1 }
            } else {
                toWrite.append(r); report.added += 1
            }
        }
        try repo.saveMany(toWrite)
        return report
    }

    public struct ImportReport: Equatable, Sendable {
        public var added = 0, replaced = 0, skipped = 0
        /// Rounds that were written but carry problems the shooter should look at.
        public var issues: [String: [ValidationIssue]] = [:]
        public var summary: String {
            var s = "\(added) added, \(replaced) replaced, \(skipped) already present."
            if !issues.isEmpty { s += " \(issues.count) with values to check." }
            return s
        }
    }
}

#if canImport(CoreTransferable)
import CoreTransferable
import UniformTypeIdentifiers

/// A backup as something `ShareLink` can hand to Files, AirDrop or Mail.
public struct BackupFile: Transferable, Sendable {
    public let data: Data
    public let filename: String
    public init(data: Data, filename: String) { self.data = data; self.filename = filename }
    public init(rounds: [Round], appVersion: String, now: Date = Date()) throws {
        self.init(data: try Backup.encode(rounds, now: now, appVersion: appVersion),
                  filename: "TrapShooterPro-backup-\(DateText.day(now)).\(Backup.fileExtension)")
    }
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName { $0.filename }
    }
}
#endif
