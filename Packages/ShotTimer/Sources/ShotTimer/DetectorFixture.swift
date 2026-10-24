import Foundation

/// One recording with known answers: the detector regression set (Phase 4). A fixture is a JSON file beside its
/// audio in `Tools/detector-fixtures/`; `DetectorRegressionTests` runs every one and compares against the live
/// detector's times. Tolerances come from the phase plan: 7 ms on the call to 1st shot interval.
///
/// ```json
/// {
///   "name": "2026-10-18 mic test, DJI, station 3",
///   "audio": "2026-10-18-dji-s3.m4a",
///   "receiver": "DJI Mic Mini 2",
///   "notes": "windy, two shooters; the second shooter's shots must be ignored",
///   "settings": { "callDb": 85, "shotDb": 112 },
///   "toleranceMs": 7,
///   "targets": [
///     { "firstMs": 612, "secondMs": 1034 },
///     { "firstMs": 587, "secondMs": null }
///   ]
/// }
/// ```
public struct DetectorFixture: Codable, Equatable, Sendable {
    /// Expected times for one target, ms from the call onset, as read off the waveform.
    public struct Target: Codable, Equatable, Sendable {
        public var firstMs: Double
        public var secondMs: Double?
        public init(firstMs: Double, secondMs: Double? = nil) { self.firstMs = firstMs; self.secondMs = secondMs }
    }

    /// Timer settings the recording was made with; fields left out keep the app's defaults.
    public struct Settings: Codable, Equatable, Sendable {
        public var callDb: Double?
        public var shotDb: Double?
        public var gateDb: Double?
        public var secondWinMs: Double?
        public var offset: Double?
        public init() {}
        /// The app's `TimerSettings` with these overrides applied.
        public var timerSettings: TimerSettings {
            var s = TimerSettings()
            if let v = callDb { s.callDb = v }
            if let v = shotDb { s.shotDb = v }
            if let v = gateDb { s.gateDb = v }
            if let v = secondWinMs { s.secondWinMs = v }
            if let v = offset { s.offset = v }
            return s
        }
    }

    /// One difference between the fixture and the detector.
    public struct Mismatch: Equatable, Sendable, CustomStringConvertible {
        public enum Kind: Equatable, Sendable { case missing, extra, first(expected: Double, got: Double), second(expected: Double?, got: Double?) }
        public var target: Int
        public var kind: Kind
        public var description: String {
            switch kind {
            case .missing: return "target \(target): expected but not detected"
            case .extra: return "target \(target): detected but not expected"
            case .first(let e, let g): return "target \(target): 1st shot expected \(e) ms, got \(g) ms"
            case .second(let e, let g): return "target \(target): 2nd shot expected \(e.map { "\($0) ms" } ?? "none"), got \(g.map { "\($0) ms" } ?? "none")"
            }
        }
    }

    public var name: String
    public var audio: String
    public var receiver: String?
    public var notes: String?
    public var settings: Settings?
    public var toleranceMs: Double?
    public var targets: [Target]

    /// The plan's tolerance when the fixture does not say otherwise.
    public static let defaultToleranceMs = 7.0

    public init(name: String, audio: String, targets: [Target], receiver: String? = nil, notes: String? = nil,
                settings: Settings? = nil, toleranceMs: Double? = nil) {
        self.name = name; self.audio = audio; self.targets = targets; self.receiver = receiver; self.notes = notes
        self.settings = settings; self.toleranceMs = toleranceMs
    }

    /// Reads one fixture. The audio path is resolved beside the JSON.
    public static func load(_ url: URL) throws -> (fixture: DetectorFixture, audio: URL) {
        let data = try Data(contentsOf: url)
        let fixture = try JSONDecoder().decode(DetectorFixture.self, from: data)
        return (fixture, url.deletingLastPathComponent().appendingPathComponent(fixture.audio))
    }

    /// Every `*.json` in `folder` that decodes, sorted by file name. Missing folder: empty.
    public static func all(in folder: URL) -> [(fixture: DetectorFixture, audio: URL)] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [] }
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { try? load($0) }
    }

    /// `Tools/detector-fixtures` in this repository, found from this source file; nil outside a checkout.
    public static var repositoryFolder: URL? {
        var url = URL(fileURLWithPath: #filePath)                 // Packages/ShotTimer/Sources/ShotTimer/DetectorFixture.swift
        for _ in 0..<5 { url.deleteLastPathComponent() }
        let folder = url.appendingPathComponent("Tools/detector-fixtures", isDirectory: true)
        return FileManager.default.fileExists(atPath: folder.path) ? folder : nil
    }

    /// Compares the detector's result with the expected targets, in order.
    public func mismatches(against result: FileAnalyzer.Result) -> [Mismatch] {
        let tol = toleranceMs ?? DetectorFixture.defaultToleranceMs
        var out: [Mismatch] = []
        for i in 0..<max(targets.count, result.targets.count) {
            guard i < targets.count else { out.append(Mismatch(target: i + 1, kind: .extra)); continue }
            guard i < result.targets.count else { out.append(Mismatch(target: i + 1, kind: .missing)); continue }
            let e = targets[i], g = result.targets[i]
            if abs(e.firstMs - g.firstMs) > tol { out.append(Mismatch(target: i + 1, kind: .first(expected: e.firstMs, got: g.firstMs))) }
            switch (e.secondMs, g.secondMs) {
            case (nil, nil): break
            case (let a?, let b?) where abs(a - b) <= tol: break
            default: out.append(Mismatch(target: i + 1, kind: .second(expected: e.secondMs, got: g.secondMs)))
            }
        }
        return out
    }
}
