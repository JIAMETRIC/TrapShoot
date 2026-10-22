import XCTest
import TrapCore
@testable import TrapReports

final class TrapReportsTests: XCTestCase {
    private func round() -> Round {
        var r = Round(id: "r1", createdAt: "2026-10-22T07:00:00.000Z", date: "2026-10-22", startTime: "09:30")
        r.sessionId = "20261022-0930-MT"; r.place = "Capri Range"; r.sky = "part"; r.wind = "light"; r.temperature = 24; r.humidity = 55
        r.directions[0] = .left; r.results[0] = .hitFirst; r.firstShot[0] = 0.704
        return r
    }

    func testFilenamesAndSafety() {
        XCTAssertEqual(Exporters.safeFilename("a b/c:d.csv"), "a-b-c-d.csv")
        XCTAssertEqual(Exporters.safeFilename("///"), "-")
        XCTAssertEqual(Exporters.reportBase(for: round()), "TrapShooterPro-20261022-0930-MT")
        var noSession = round(); noSession.sessionId = ""
        XCTAssertEqual(Exporters.reportBase(for: noSession), "TrapShooterPro-20261022")
    }

    func testCSVAndBackupExporters() throws {
        let csv = CSVRoundsExporter(breakModel: BreakDistanceModel())
        XCTAssertEqual(csv.filename(for: [round()]), "TrapShooterPro-20261022-0930-MT.csv")
        let text = String(decoding: try csv.data(for: [round()]), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("round_id,shooter_id,"))
        XCTAssertEqual(text.split(separator: "\n").count, 2, "header + one recorded target")
        XCTAssertThrowsError(try csv.data(for: []))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("reports-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let result = try csv.export([round()], to: dir)
        XCTAssertEqual(result.format, .csv); XCTAssertGreaterThan(result.bytes, 100)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.url.path))
        let backup = BackupExporter(appVersion: "8.0")
        let data = try backup.data(for: [round()])
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("trapshooterpro-backup"))
    }

    func testFactoryAndConditions() {
        XCTAssertEqual(ExporterFactory.formats(for: .round), [.png, .pdf, .csv])
        XCTAssertEqual(ExporterFactory.formats(for: .library), [.json, .csv])
        XCTAssertNotNil(ExporterFactory.roundsExporter(.csv, breakModel: BreakDistanceModel(), appVersion: "8.0"))
        XCTAssertNil(ExporterFactory.roundsExporter(.png, breakModel: BreakDistanceModel(), appVersion: "8.0"))
        XCTAssertNotNil(ExporterFactory.roundExporter(.pdf, breakModel: BreakDistanceModel(), appVersion: "8.0"))
        XCTAssertEqual(ScorecardView.conditions(round()), "Part cloud, 24°C, 55% humidity, light wind")
    }

    @MainActor
    func testScorecardRenders() throws {
        let png = try ScorecardImageExporter(breakModel: BreakDistanceModel(), appVersion: "8.0").data(for: round())
        XCTAssertGreaterThan(png.count, 10_000)
        let pdf = try ScorecardPDFExporter(breakModel: BreakDistanceModel(), appVersion: "8.0").data(for: round())
        XCTAssertTrue(String(decoding: pdf.prefix(5), as: UTF8.self).hasPrefix("%PDF"))
    }
}
