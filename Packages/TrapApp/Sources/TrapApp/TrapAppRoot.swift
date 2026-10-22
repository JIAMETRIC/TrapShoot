import SwiftUI
import TrapDesign

/// The whole app below the `@main` entry. The app target's only view.
public struct TrapAppRoot: View {
    public init() {}

    public var body: some View {
        BreakpointReader {
            Text(AppSection.record.title)
                .bwDisplay()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BW.surface)
        }
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
