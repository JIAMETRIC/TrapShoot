import SwiftUI
import TrapCore
import TrapDesign
import TrapPlatform

/// Analysis: overview tiles, score trend, trap analysis with findings, and the dimension tables. Loads every round
/// (`fetchAll` is allowed here, CLAUDE.md rule 14) and computes off the view with the TrapCore functions the golden
/// tests cover.
@MainActor
struct AnalysisScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(\.breakpoint) private var breakpoint
    @State private var rounds: [Round] = []
    @State private var scheme: Int?
    @State private var loaded = false

    var body: some View {
        let chosen = scheme ?? Analysis.dominantScheme(rounds) ?? Schemes.defaultScheme
        let overview = Analysis.overview(rounds)
        ScreenScroll(title: "Analysis") {
            if loaded && rounds.isEmpty {
                Text("No rounds yet. Analysis appears after your first recorded round.")
                    .font(BWFont.secondary).foregroundStyle(BW.textSecondary)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: BWMetrics.s3), count: breakpoint.tileColumns), spacing: BWMetrics.s3) {
                    BWKPITile("Rounds", value: "\(overview.rounds)", sub: "\(overview.fullRounds) full")
                    // every tile has a sub line so a row lines up
                    BWKPITile("Avg score", value: overview.averageScoreText, sub: "full rounds")
                    BWKPITile("Best score", value: overview.bestScoreText, sub: "of 25")
                    BWKPITile("Hit rate", value: overview.hitRateText, sub: "\(overview.targets) targets")
                    BWKPITile("1st barrel", value: overview.firstBarrelText, sub: "broken with the 1st shot")
                    BWKPITile("2nd barrel", value: overview.secondBarrelText, sub: "broken with the 2nd shot")
                }
                TrendBars(points: Analysis.trend(rounds))
                TrapSection(analysis: TrapLog.measure("trap analysis") { Analysis.trapAnalysis(rounds, scheme: chosen) }, scheme: chosen,
                            schemes: Analysis.schemeCounts(rounds).keys.sorted()) { scheme = $0 }
                ForEach(Analysis.tables(rounds), id: \.title) { t in TableCard(table: t) }
            }
        }
        .task(id: app.libraryVersion) { load() }
        .onChange(of: app.record.round.recorded) { _, _ in load() }
    }

    private func load() {
        rounds = (try? TrapLog.measure("analysis load") { try app.repository.fetchAll() }) ?? []
        loaded = true
    }
}

/// Scores of the latest rounds as bars, oldest left.
@MainActor
private struct TrendBars: View {
    let points: [TrendPoint]
    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s2) {
            BWSectionLabel("Score trend")
            if points.isEmpty {
                Text("Full rounds appear here.").font(BWFont.note).foregroundStyle(BW.textMuted)
            } else {
                HStack(alignment: .bottom, spacing: BWMetrics.s1) {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        VStack(spacing: 2) {
                            Text("\(p.score)").font(BWFont.value(.caption2, weight: .regular)).foregroundStyle(BW.textSecondary)
                            RoundedRectangle(cornerRadius: BWMetrics.radiusXS).fill(BW.ink)
                                .frame(height: CGFloat(p.score) / 25 * 120)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(p.date): \(p.score)")
                    }
                }
                .frame(height: 140, alignment: .bottom)
            }
        }
        .bwCard()
    }
}

/// Per-trap hit rates for one scheme, findings in words, station misses.
@MainActor
private struct TrapSection: View {
    let analysis: TrapAnalysis
    let scheme: Int
    let schemes: [Int]
    let pick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s3) {
            BWSectionLabel("Trap analysis") {
                Menu("Scheme \(scheme)") {
                    ForEach(schemes, id: \.self) { n in Button("Scheme \(n)") { pick(n) } }
                }
                .font(BWFont.secondary.weight(.semibold))
            }
            if analysis.totals.shots == 0 {
                Text("No targets recorded with scheme \(scheme).").font(BWFont.note).foregroundStyle(BW.textMuted)
            } else {
                ForEach(Analysis.findings(analysis), id: \.self) { f in
                    HStack(alignment: .top, spacing: BWMetrics.s2) {
                        Circle().fill(BW.ink).frame(width: BWMetrics.featureBullet, height: BWMetrics.featureBullet).padding(.top, 7)
                        Text(f).font(BWFont.secondary).foregroundStyle(BW.text)
                    }
                }
                BWTableHeader(["Trap", "Stn", "Angle", "Height", "Shots", "Hit", "Avg 1st"])
                ForEach(Array(analysis.traps.enumerated()), id: \.offset) { k, t in
                    HStack {
                        cell("\(t.number)"); cell("\(t.station)"); cell(Analysis.angleLabel(t.label)); cell(Analysis.heightLabel(t.height))
                        cell("\(t.shots)"); cell(Analysis.percent(t.hits, t.shots)); cell(t.averageTime.map { JSText.fixed($0, 3) } ?? "–")
                    }
                    .padding(.vertical, BWMetrics.s1)
                    .bwTableRow(index: k)
                }
            }
        }
        .bwCard()
    }

    private func cell(_ t: String) -> some View {
        Text(t).font(BWFont.value(.footnote, weight: .regular)).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One dimension table (angle, height, temperature, humidity, blocks …).
@MainActor
private struct TableCard: View {
    let table: AnalysisTable
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BWSectionLabel(table.title).padding(.bottom, BWMetrics.s2)
            BWTableHeader(["", "Targets", "Hit", "1st barrel"])
            ForEach(Array(table.rows.enumerated()), id: \.offset) { k, r in
                HStack {
                    Text(r.key).font(BWFont.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    cell("\(r.targets)"); cell(Analysis.percent(r.hits, r.targets)); cell(Analysis.percent(r.firstShotHits, r.targets))
                }
                .padding(.vertical, BWMetrics.s2)
                .bwTableRow(index: k)
            }
        }
        .bwCard()
    }
    private func cell(_ t: String) -> some View {
        Text(t).font(BWFont.value(.footnote, weight: .regular)).frame(maxWidth: .infinity, alignment: .leading)
    }
}
