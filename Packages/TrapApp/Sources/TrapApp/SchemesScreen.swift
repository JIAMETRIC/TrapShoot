import SwiftUI
import TrapCore
import TrapDesign

/// The ten ISSF schemes, one at a time: 15 machines with side, angle and height, grouped by station.
@MainActor
struct SchemesScreen: View {
    @State private var scheme = Schemes.defaultScheme

    var body: some View {
        ScreenScroll(title: "Schemes") {
            Picker("Scheme", selection: $scheme) {
                ForEach(Array(Schemes.numbers), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 0) {
                BWSectionLabel("Scheme \(scheme)").padding(.bottom, BWMetrics.s2)
                BWTableHeader(["Stn", "Dir", "Trap", "Angle", "Height"])
                ForEach(1...Round.stationCount, id: \.self) { station in
                    ForEach(Direction.allCases, id: \.self) { d in
                        if let m = Schemes.machine(scheme: scheme, station: station, direction: d) {
                            HStack {
                                cell(d == .right ? "\(station)" : "")
                                cell(d.name); cell("\(m.number)"); cell(m.label == "0" ? "0°" : "\(m.angle)° \(m.side)")
                                cell(JSText.number(m.height) + " m")
                            }
                            .padding(.vertical, BWMetrics.s2)
                            .bwTableRow(index: (station - 1) * 3 + d.machineOffset)
                        }
                    }
                }
            }
            .bwCard()
            Text("Each station throws 2 right, 1 straight and 2 left over 25 targets. Height is at 10 m.")
                .font(BWFont.note).foregroundStyle(BW.textMuted)
        }
    }

    private func cell(_ t: String) -> some View {
        Text(t).font(BWFont.value(.footnote, weight: .regular)).frame(maxWidth: .infinity, alignment: .leading)
    }
}
