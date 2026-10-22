import Foundation
import TrapCore

/// Where the app keeps things on disk. Everything is local; everything is in the device backup.
public enum AppPaths {
    public static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    public static var applicationSupport: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    /// Same folder `RoundRecorder` writes to; visible in the Files app under On My iPhone > TrapShoot > Recordings.
    public static var recordings: URL { documents.appendingPathComponent(AppConstants.recordingsFolder, isDirectory: true) }
    /// SwiftData store (`TrapShooterPro.store`) lives here.
    public static var store: URL { applicationSupport.appendingPathComponent(AppConstants.storeName + ".store") }

    /// Rounds and recordings are readable after the first unlock, so the timer works on a locked, pocketed phone's
    /// next unlock without waiting, and are still encrypted at rest.
    public static func applyFileProtection(_ url: URL) {
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
    }
}

/// One saved round-audio file and its settings sidecar.
public struct Recording: Identifiable, Equatable, Sendable {
    public let url: URL
    public let sidecar: URL?
    public let bytes: Int64
    public let modified: Date
    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}

/// Lists and deletes recordings. Recordings are the only files that grow (about 1 MB per minute), so the
/// Settings > Data screen shows their total and offers to delete old ones.
public final class RecordingsStore {
    public let folder: URL
    public init(folder: URL = AppPaths.recordings) { self.folder = folder }

    public func list() -> [Recording] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) else { return [] }
        return items.filter { $0.pathExtension.lowercased() == "m4a" }.compactMap { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let sidecar = url.deletingPathExtension().appendingPathExtension("json")
            return Recording(url: url, sidecar: fm.fileExists(atPath: sidecar.path) ? sidecar : nil,
                             bytes: Int64(values?.fileSize ?? 0), modified: values?.contentModificationDate ?? .distantPast)
        }.sorted { $0.modified > $1.modified }
    }

    public var totalBytes: Int64 { list().reduce(0) { $0 + $1.bytes } }

    public func delete(_ r: Recording) throws {
        try FileManager.default.removeItem(at: r.url)
        if let s = r.sidecar { try? FileManager.default.removeItem(at: s) }
    }

    /// Deletes recordings older than `days`, returns how many.
    @discardableResult
    public func deleteOlder(than days: Int, now: Date = Date()) -> Int {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        var n = 0
        for r in list() where r.modified < cutoff { if (try? delete(r)) != nil { n += 1 } }
        return n
    }
}

/// What the Data screen shows: how big things are and how much room is left.
public struct StorageReport: Equatable, Sendable {
    public let storeBytes: Int64
    public let recordingsBytes: Int64
    public let recordingsCount: Int
    public let freeBytes: Int64?

    public static func measure(store: URL = AppPaths.store, recordings: RecordingsStore = RecordingsStore()) -> StorageReport {
        let fm = FileManager.default
        var storeBytes: Int64 = 0
        // SwiftData keeps the store plus -wal and -shm files next to it
        for suffix in ["", "-wal", "-shm"] {
            let p = store.path + suffix
            if let attrs = try? fm.attributesOfItem(atPath: p), let size = attrs[.size] as? NSNumber { storeBytes += size.int64Value }
        }
        let list = recordings.list()
        let free = (try? AppPaths.documents.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
        return StorageReport(storeBytes: storeBytes, recordingsBytes: list.reduce(0) { $0 + $1.bytes }, recordingsCount: list.count, freeBytes: free)
    }

    public static func text(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
    /// Under 200 MB free: warn before starting round audio.
    public var lowOnSpace: Bool { (freeBytes ?? .max) < 200 * 1_048_576 }
}

/// A Codable value in UserDefaults. Settings are small; this keeps them typed and in one place.
public struct CodableDefaults<Value: Codable> {
    public let key: String
    public let fallback: Value
    private let defaults: UserDefaults
    public init(key: String, fallback: Value, defaults: UserDefaults = .standard) {
        self.key = key; self.fallback = fallback; self.defaults = defaults
    }
    public func load() -> Value {
        guard let data = defaults.data(forKey: key), let v = try? JSONDecoder().decode(Value.self, from: data) else { return fallback }
        return v
    }
    public func save(_ value: Value) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
    public func reset() { defaults.removeObject(forKey: key) }
}

/// Version, build and channel, for the About screen and support mails.
public enum AppInfo {
    public static var displayName: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? AppConstants.displayName }
    public static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    public static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0" }
    public static var bundleID: String { Bundle.main.bundleIdentifier ?? "" }
    public static var versionLine: String { "\(version) (\(build))" }
    /// TestFlight builds carry a sandbox receipt.
    public static var isTestFlight: Bool { Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" }
    public static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    public static var channel: String { isDebug ? "Debug" : isTestFlight ? "TestFlight" : "App Store" }
}
