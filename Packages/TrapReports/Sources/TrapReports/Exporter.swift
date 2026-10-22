import Foundation
import TrapCore
import TrapData
import UniformTypeIdentifiers

public enum ExportFormat: String, CaseIterable, Sendable {
    case csv, json, png, pdf
    public var contentType: UTType {
        switch self { case .csv: return .commaSeparatedText; case .json: return .json; case .png: return .png; case .pdf: return .pdf }
    }
    public var fileExtension: String { rawValue }
    public var name: String {
        switch self { case .csv: return "CSV"; case .json: return "Backup"; case .png: return "Image"; case .pdf: return "PDF" }
    }
}

public struct ExportResult: Equatable, Sendable {
    public let url: URL
    public let filename: String
    public let format: ExportFormat
    public let bytes: Int
}

public enum ExportError: Error, Equatable, UserFacingError {
    case nothingToExport
    case renderFailed
    public var message: String {
        switch self { case .nothingToExport: return "There is nothing to export yet."; case .renderFailed: return "The scorecard could not be drawn." }
    }
}

/// One kind of document from one kind of input. `export` is the template method: produce bytes, name the file,
/// write it atomically to a folder, hand back the result. Subtypes only say what the bytes and the name are.
/// Not actor‑bound: CSV and backup exports can run anywhere. The two scorecard renderers need the main actor and
/// say so inside their own `data(for:)`.
public protocol DocumentExporter<Input> {
    associatedtype Input
    var format: ExportFormat { get }
    func filename(for input: Input) -> String
    func data(for input: Input) throws -> Data
}

public extension DocumentExporter {
    func export(_ input: Input, to folder: URL = FileManager.default.temporaryDirectory) throws -> ExportResult {
        let data = try self.data(for: input)
        let name = Exporters.safeFilename(filename(for: input))
        let url = folder.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return ExportResult(url: url, filename: name, format: format, bytes: data.count)
    }
}

public enum Exporters {
    /// Characters a file name may carry across Files, AirDrop and Mail.
    public static func safeFilename(_ s: String) -> String {
        let cleaned = s.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
        return cleaned.isEmpty ? "export" : cleaned
    }
    /// "TrapShooterPro-20261022-0930-MT-scorecard" or the date when there is no session id.
    public static func reportBase(for r: Round) -> String {
        "TrapShooterPro-" + (r.sessionId.isEmpty ? r.date.replacingOccurrences(of: "-", with: "") : r.sessionId)
    }
}

// MARK: concrete exporters

/// One row per recorded target; one round or many.
public struct CSVRoundsExporter: DocumentExporter {
    public typealias Input = [Round]
    public let format = ExportFormat.csv
    public let breakModel: BreakDistanceModel
    public init(breakModel: BreakDistanceModel) { self.breakModel = breakModel }
    public func filename(for rounds: [Round]) -> String {
        rounds.count == 1 ? Exporters.reportBase(for: rounds[0]) + ".csv" : "TrapShooterPro-rounds-\(DateText.day(Date())).csv"
    }
    public func data(for rounds: [Round]) throws -> Data {
        guard !rounds.isEmpty else { throw ExportError.nothingToExport }
        return Data(CSVExport.csv(rounds: rounds, breakModel: breakModel).utf8)
    }
}

/// The whole library as one restorable file.
public struct BackupExporter: DocumentExporter {
    public typealias Input = [Round]
    public let format = ExportFormat.json
    public let appVersion: String
    public init(appVersion: String) { self.appVersion = appVersion }
    public func filename(for rounds: [Round]) -> String { "TrapShooterPro-backup-\(DateText.day(Date())).\(Backup.fileExtension)" }
    public func data(for rounds: [Round]) throws -> Data { try Backup.encode(rounds, appVersion: appVersion) }
}

/// Which screen is exporting; the factory picks the exporter.
public enum ExportContext: Sendable { case round, roundList, library }

public enum ExporterFactory {
    /// Formats a screen offers.
    public static func formats(for context: ExportContext) -> [ExportFormat] {
        switch context { case .round: return [.png, .pdf, .csv]; case .roundList: return [.csv]; case .library: return [.json, .csv] }
    }

    public static func roundsExporter(_ format: ExportFormat, breakModel: BreakDistanceModel, appVersion: String) -> (any DocumentExporter<[Round]>)? {
        switch format {
        case .csv: return CSVRoundsExporter(breakModel: breakModel)
        case .json: return BackupExporter(appVersion: appVersion)
        case .png, .pdf: return nil
        }
    }

    public static func roundExporter(_ format: ExportFormat, breakModel: BreakDistanceModel, appVersion: String) -> (any DocumentExporter<Round>)? {
        switch format {
        case .png: return ScorecardImageExporter(breakModel: breakModel, appVersion: appVersion)
        case .pdf: return ScorecardPDFExporter(breakModel: breakModel, appVersion: appVersion)
        case .csv: return SingleRoundCSVExporter(breakModel: breakModel)
        case .json: return nil
        }
    }
}

/// CSV of one round, as its own type so the factory can return `DocumentExporter<Round>`.
public struct SingleRoundCSVExporter: DocumentExporter {
    public typealias Input = Round
    public let format = ExportFormat.csv
    let inner: CSVRoundsExporter
    public init(breakModel: BreakDistanceModel) { inner = CSVRoundsExporter(breakModel: breakModel) }
    public func filename(for r: Round) -> String { inner.filename(for: [r]) }
    public func data(for r: Round) throws -> Data { try inner.data(for: [r]) }
}
