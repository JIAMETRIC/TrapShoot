import Observation
import SwiftUI
import TrapCore
import TrapData
import TrapDesign
import TrapPlatform
import TrapReports

/// The Rounds list: column fetches through `fetchSummaries` with a filter, 60 rows a page (CLAUDE.md rule 14).
@MainActor
@Observable
final class RoundsModel {
    static let pageSize = 60
    // The list reloads when `filter` changes (the view watches it).
    var text = ""
    var scheme: Int?
    var type: String?
    var fullOnly = false
    private(set) var rows: [RoundSummary] = []
    private(set) var total = 0
    private(set) var error: DisplayError?
    /// The last deleted round, kept for Undo.
    private(set) var deleted: Round?

    @ObservationIgnored let repository: RoundRepository
    init(repository: RoundRepository) { self.repository = repository }

    var filter: RoundFilter { RoundFilter(scheme: scheme, type: type, fullOnly: fullOnly, text: text) }
    var hasMore: Bool { rows.count < total }

    func reload() {
        do {
            rows = try TrapLog.measure("rounds first page") { try repository.fetchSummaries(filter, limit: Self.pageSize, offset: 0) }
            total = try repository.count(filter)
            error = nil
        } catch { self.error = DisplayError(any: error) }
    }

    func loadMore() {
        guard hasMore else { return }
        do { rows += try repository.fetchSummaries(filter, limit: Self.pageSize, offset: rows.count) } catch { self.error = DisplayError(any: error) }
    }

    func delete(_ id: String) {
        do {
            deleted = try repository.fetch(id: id)
            try repository.delete(id: id)
            reload()
        } catch { self.error = DisplayError(any: error) }
    }

    func undoDelete() {
        guard let r = deleted else { return }
        do { try repository.save(r); deleted = nil; reload() } catch { self.error = DisplayError(any: error) }
    }
}

@MainActor
struct RoundsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.breakpoint) private var breakpoint
    @State private var model: RoundsModel?
    @State private var selected: String?

    var body: some View {
        Group {
            if let model {
                AdaptiveSplit {
                    RoundsList(model: model, selected: $selected)
                } detail: {
                    if let id = selected { RoundDetail(id: id, rounds: model) } else {
                        Text("Pick a round").font(BWFont.secondary).foregroundStyle(BW.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity).background(BW.surface)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Rounds")
        .navigationDestination(for: String.self) { id in
            if let model { RoundDetail(id: id, rounds: model) }
        }
        .task(id: app.libraryVersion) {
            let m = model ?? RoundsModel(repository: app.repository)
            m.reload()
            model = m
        }
        .onChange(of: app.record.round) { _, _ in model?.reload() }
    }
}

@MainActor
private struct RoundsList: View {
    @Bindable var model: RoundsModel
    @Binding var selected: String?
    @Environment(\.breakpoint) private var breakpoint

    var body: some View {
        List {
            Section {
                filters
                if let e = model.error { MessageLine(error: e, note: nil) }
                if model.deleted != nil {
                    Button("Undo delete") { model.undoDelete() }.buttonStyle(.bwSecondary)
                }
                Text("\(model.total) " + (model.total == 1 ? "round" : "rounds")).font(BWFont.note).foregroundStyle(BW.textMuted)
            }
            .listRowBackground(Color.clear)
            Section {
                if model.rows.isEmpty {
                    Text("No saved rounds yet. Record a round on the Record tab. It appears here with its score.")
                        .font(BWFont.secondary).foregroundStyle(BW.textSecondary)
                }
                ForEach(model.rows) { row in
                    rowLink(row)
                        .swipeActions { Button("Delete", role: .destructive) { model.delete(row.id) } }
                        .onAppear { if row.id == model.rows.last?.id { model.loadMore() } }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(BW.surface)
        .searchable(text: $model.text, prompt: "Range or session id")
        .onChange(of: model.filter) { _, _ in model.reload() }
    }

    @ViewBuilder private func rowLink(_ row: RoundSummary) -> some View {
        if breakpoint.isSplit {
            Button { selected = row.id } label: { RoundRow(row: row, selected: selected == row.id) }.buttonStyle(.plain)
        } else {
            NavigationLink(value: row.id) { RoundRow(row: row, selected: false) }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: BWMetrics.s2) {
                Menu(model.scheme.map { "Scheme \($0)" } ?? "All schemes") {
                    Button("All schemes") { model.scheme = nil }
                    ForEach(Array(Schemes.numbers), id: \.self) { n in Button("Scheme \(n)") { model.scheme = n } }
                }
                Menu(model.type ?? "All types") {
                    Button("All types") { model.type = nil }
                    Button("Training") { model.type = "Training" }
                    Button("Competition") { model.type = "Competition" }
                }
                Toggle("Full rounds", isOn: $model.fullOnly).toggleStyle(.button)
            }
            .font(BWFont.secondary.weight(.semibold))
        }
    }
}

@MainActor
private struct RoundRow: View {
    let row: RoundSummary
    let selected: Bool
    var body: some View {
        HStack(spacing: BWMetrics.s3) {
            VStack(spacing: 0) {
                Text("\(row.score)").font(BWFont.valueLarge)
                Text("/\(row.recorded)").font(BWFont.note).foregroundStyle(BW.textMuted)
            }
            .frame(minWidth: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.date + (row.sessionId.isEmpty ? "" : " · " + row.sessionId)).font(BWFont.body.weight(.semibold))
                Text([row.place, "Scheme \(row.scheme)", row.type].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(BWFont.secondary).foregroundStyle(BW.textSecondary)
            }
            Spacer()
            if row.isFull { BWPill("25", status: BW.success) }
        }
        .padding(.vertical, BWMetrics.s1)
        .contentShape(Rectangle())
        .listRowBackground(selected ? BW.surfaceAlt : BW.paper)
        .accessibilityElement(children: .combine)
    }
}

/// One round: the scorecard drawn live, open in Record, share, delete.
@MainActor
struct RoundDetail: View {
    let id: String
    let rounds: RoundsModel
    @Environment(AppModel.self) private var app
    @AppStorage(AppState.sectionKey) private var section = AppSection.record.rawValue
    @State private var round: Round?

    var body: some View {
        ScreenScroll(title: round?.sessionId ?? "Round") {
            if let r = round {
                HStack(spacing: BWMetrics.s2) {
                    Button("Open in Record") { app.record.open(id: r.id); section = AppSection.record.rawValue }
                        .buttonStyle(.bwPrimary)
                    ShareRoundButton(round: r)
                }
                ScorecardView(round: r, breakModel: BreakDistanceModel(settings: app.settings.breakDistance), appVersion: AppInfo.version)
                    .frame(width: ScorecardView.pageSize.width, height: ScorecardView.pageSize.height)
                    .scaleEffect(0.6, anchor: .topLeading)
                    .frame(width: ScorecardView.pageSize.width * 0.6, height: ScorecardView.pageSize.height * 0.6, alignment: .topLeading)
                    .environment(\.colorScheme, .light)
                    .bwShadow(.raised)
                    .accessibilityLabel("Scorecard, \(r.score) of \(r.recorded)")
            } else {
                Text("This round is no longer saved.").font(BWFont.secondary).foregroundStyle(BW.textMuted)
            }
        }
        .task(id: id) { round = try? app.repository.fetch(id: id) }
    }
}
