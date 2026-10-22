import SwiftUI
import TrapCore
import TrapDesign
import TrapPlatform

/// The whole app below the `@main` entry. The app target's only view.
@MainActor
public struct TrapAppRoot: View {
    @State private var app: AppModel

    public init() { _app = State(initialValue: AppModel()) }
    init(app: AppModel) { _app = State(initialValue: app) }

    public var body: some View {
        BreakpointReader { AppShell() }
            .environment(app)
            .environment(app.record)
            .lifecycle(app.lifecycle)
            .tint(BW.ink)
    }
}

/// The six places of the app: tabs on iPhone, sidebar rows on iPad.
public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case record, timer, rounds, analysis, schemes, settings
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .record: return "Record"
        case .timer: return "Timer"
        case .rounds: return "Rounds"
        case .analysis: return "Analysis"
        case .schemes: return "Schemes"
        case .settings: return "Settings"
        }
    }
    public var symbol: String {
        switch self {
        case .record: return "square.grid.3x3"
        case .timer: return "stopwatch"
        case .rounds: return "list.bullet.rectangle"
        case .analysis: return "chart.bar"
        case .schemes: return "tablecells"
        case .settings: return "gearshape"
        }
    }
}

/// `TabView` on iPhone, `NavigationSplitView` with an ink sidebar on iPad. The selected place survives a relaunch.
@MainActor
struct AppShell: View {
    @Environment(\.breakpoint) private var breakpoint
    @Environment(AppModel.self) private var app
    @AppStorage(AppState.sectionKey) private var selectedRaw = AppSection.record.rawValue

    private var selection: Binding<AppSection> {
        Binding(get: { AppSection(rawValue: selectedRaw) ?? .record }, set: { selectedRaw = $0.rawValue })
    }

    var body: some View {
        Group {
            if breakpoint.isSplit {
                NavigationSplitView {
                    Sidebar(selection: selection)
                        .navigationSplitViewColumnWidth(breakpoint.sidebarWidth)
                } detail: {
                    NavigationStack { SectionScreen(section: selection.wrappedValue) }
                }
            } else {
                TabView(selection: selection) {
                    ForEach(AppSection.allCases) { s in
                        NavigationStack { SectionScreen(section: s) }
                            .tabItem { Label(s.title, systemImage: s.symbol) }
                            .tag(s)
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if let problem = app.storeProblem {
                Text(problem)
                    .font(BWFont.note)
                    .foregroundStyle(BW.danger.foreground)
                    .padding(BWMetrics.s3)
                    .frame(maxWidth: .infinity)
                    .background(BW.danger.background)
            }
        }
    }
}

/// The ink sidebar on iPad.
@MainActor
private struct Sidebar: View {
    @Binding var selection: AppSection
    var body: some View {
        List {
            ForEach(AppSection.allCases) { s in
                Button { selection = s } label: {
                    Label(s.title, systemImage: s.symbol)
                        .font(BWFont.body.weight(selection == s ? .bold : .regular))
                        .foregroundStyle(selection == s ? BW.ink : BW.onInk)
                        .frame(maxWidth: .infinity, minHeight: BWMetrics.controlHeight, alignment: .leading)
                        .padding(.horizontal, BWMetrics.s3)
                        .background(selection == s ? BW.onInk : Color.clear, in: RoundedRectangle(cornerRadius: BWMetrics.radiusMD))
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .accessibilityAddTraits(selection == s ? .isSelected : [])
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(BW.ink)
        .navigationTitle(AppConstants.displayName)
    }
}

/// One place of the app.
@MainActor
struct SectionScreen: View {
    let section: AppSection
    @Environment(\.breakpoint) private var breakpoint

    var body: some View {
        switch section {
        case .record:
            if breakpoint.isSplit {
                AdaptiveSplit { RecordScreen() } detail: { TimerScreen() }
            } else {
                RecordScreen()
            }
        case .timer: TimerScreen()
        case .rounds: RoundsScreen()
        case .analysis: AnalysisScreen()
        case .schemes: SchemesScreen()
        case .settings: SettingsScreen()
        }
    }
}
