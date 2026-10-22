import SwiftUI
import TrapCore
import TrapDesign
import TrapPlatform
import TrapReports
import UIKit

/// A file made for sharing, removed again when the share sheet closes.
struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The system share sheet. Deletes the temporary file afterwards (Phase 6: temp files removed after sharing).
@MainActor
struct ActivitySheet: UIViewControllerRepresentable {
    let file: SharedFile
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        let url = file.url
        vc.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        return vc
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// Share one round as scorecard image, PDF or CSV.
@MainActor
struct ShareRoundButton: View {
    let round: Round
    @Environment(AppModel.self) private var app
    @State private var file: SharedFile?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s1) {
            Menu {
                ForEach(ExporterFactory.formats(for: .round), id: \.self) { f in
                    Button(f.name) { export(f) }
                }
            } label: {
                Label("Share round", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: BWMetrics.actionHeight)
            }
            .buttonStyle(.bwSecondary)
            .keyboardShortcut(BWKeys.share)
            if let p = problem { Text(p).font(BWFont.note).foregroundStyle(BW.danger.foreground) }
        }
        .sheet(item: $file) { ActivitySheet(file: $0) }
    }

    private func export(_ f: ExportFormat) {
        let model = BreakDistanceModel(settings: app.settings.breakDistance)
        guard let exporter = ExporterFactory.roundExporter(f, breakModel: model, appVersion: AppInfo.version) else { return }
        do {
            let result = try TrapLog.measure("export round") { try exporter.export(round) }
            problem = nil
            file = SharedFile(url: result.url)
        } catch {
            problem = DisplayError(any: error, fallback: "The file could not be made.").text
        }
    }
}

/// Share a list of rounds as CSV or the whole library as a backup.
@MainActor
struct ShareRoundsButton: View {
    let title: String
    let format: ExportFormat
    let rounds: () throws -> [Round]
    @Environment(AppModel.self) private var app
    @State private var file: SharedFile?
    @State private var problem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s1) {
            Button { export() } label: { Label(title, systemImage: "square.and.arrow.up") }
                .buttonStyle(.bwSecondary)
            if let p = problem { Text(p).font(BWFont.note).foregroundStyle(BW.danger.foreground) }
        }
        .sheet(item: $file) { ActivitySheet(file: $0) }
    }

    private func export() {
        let model = BreakDistanceModel(settings: app.settings.breakDistance)
        guard let exporter = ExporterFactory.roundsExporter(format, breakModel: model, appVersion: AppInfo.version) else { return }
        do {
            let list = try rounds()
            guard !list.isEmpty else { throw ExportError.nothingToExport }
            let result = try exporter.export(list)
            problem = nil
            file = SharedFile(url: result.url)
        } catch {
            problem = DisplayError(any: error, fallback: "The file could not be made.").text
        }
    }
}
