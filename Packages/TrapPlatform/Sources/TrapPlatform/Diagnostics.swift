import Foundation
import MetricKit
import OSLog

/// Logging. One subsystem, one category per module, unified logging only (no files, no third parties).
/// Round data is never logged in the clear: interpolate values with `privacy: .private` unless they are
/// counts, states or durations. Console.app and `log collect` read them; the support bundle exports the last hour.
public enum TrapLog {
    public static let subsystem = "com.mtajudeen.trapshooterpro"
    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let timer = Logger(subsystem: subsystem, category: "timer")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let data = Logger(subsystem: subsystem, category: "data")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let ui = Logger(subsystem: subsystem, category: "ui")

    /// Signposts for Instruments (Time Profiler, Points of Interest): timer start, engine restart, round save, export.
    public static let signposter = OSSignposter(subsystem: subsystem, category: "performance")

    /// Measures a synchronous block as a signpost interval and returns its result.
    public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        return try body()
    }

    /// Reads the last `minutes` of this app's log entries, newest last. Used by the support bundle and the debug screen.
    public static func recentEntries(minutes: Int = 60) -> [String] {
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return [] }
        let since = store.position(date: Date().addingTimeInterval(-Double(minutes) * 60))
        let predicate = NSPredicate(format: "subsystem == %@", subsystem)
        guard let entries = try? store.getEntries(at: since, matching: predicate) else { return [] }
        let f = ISO8601DateFormatter()
        return entries.compactMap { entry -> String? in
            guard let e = entry as? OSLogEntryLog else { return nil }
            return "\(f.string(from: e.date)) [\(e.category)] \(e.composedMessage)"
        }
    }
}

/// Crash, hang and energy diagnostics from the system, without any SDK. MetricKit delivers payloads about once a
/// day; they are written as JSON into Application Support/Diagnostics for the support bundle. Nothing is uploaded.
public final class MetricsCollector: NSObject, MXMetricManagerSubscriber {
    public static let shared = MetricsCollector()
    public static var folder: URL { AppPaths.applicationSupport.appendingPathComponent("Diagnostics", isDirectory: true) }
    private override init() { super.init() }

    public func start() { MXMetricManager.shared.add(self) }
    public func stop() { MXMetricManager.shared.remove(self) }

    public func didReceive(_ payloads: [MXMetricPayload]) {
        for p in payloads { write(p.jsonRepresentation(), prefix: "metrics") }
    }
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads { write(p.jsonRepresentation(), prefix: "diagnostics") }
        TrapLog.app.error("MetricKit delivered \(payloads.count) diagnostic payload(s)")
    }

    private func write(_ data: Data, prefix: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: MetricsCollector.folder, withIntermediateDirectories: true)
        let name = "\(prefix)-\(Int(Date().timeIntervalSince1970)).json"
        try? data.write(to: MetricsCollector.folder.appendingPathComponent(name), options: .atomic)
        prune()
    }

    /// Keeps the newest 30 files.
    private func prune() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: MetricsCollector.folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let sorted = files.sorted { (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast >
                                   (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast }
        for f in sorted.dropFirst(30) { try? FileManager.default.removeItem(at: f) }
    }

    public func recentFiles() -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: MetricsCollector.folder, includingPropertiesForKeys: nil)) ?? []
    }
}

/// A text file the shooter can mail from Settings > About > Send diagnostics. Replaces "send a screenshot".
/// Contains: app and device facts, storage report, audio check line, recent log lines. No round data.
public enum SupportBundle {
    public static func make(audioLine: String, extra: [String: String] = [:]) throws -> URL {
        var lines: [String] = []
        lines.append("TrapShooterPro support bundle")
        lines.append("Generated: \(ISO8601DateFormatter().string(from: Date()))")
        lines.append("App: \(AppInfo.displayName) \(AppInfo.versionLine) \(AppInfo.channel)")
        lines.append("Device: \(deviceLine())")
        lines.append("Audio: \(audioLine)")
        let report = StorageReport.measure()
        lines.append("Storage: store \(StorageReport.text(report.storeBytes)), recordings \(report.recordingsCount) files \(StorageReport.text(report.recordingsBytes)), free \(report.freeBytes.map(StorageReport.text) ?? "?")")
        for (k, v) in extra.sorted(by: { $0.key < $1.key }) { lines.append("\(k): \(v)") }
        lines.append("")
        lines.append("--- log, last 60 minutes ---")
        lines.append(contentsOf: TrapLog.recentEntries(minutes: 60))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TrapShooterPro-diagnostics.txt")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func deviceLine() -> String {
        var sys = utsname(); uname(&sys)
        let machine = withUnsafePointer(to: &sys.machine) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
        return "\(machine), iOS \(ProcessInfo.processInfo.operatingSystemVersionString)"
    }
}
