import SwiftUI
import TrapCore
import TrapDesign

/// Record: range data and conditions, then the 25-target entry, the score strip, the ledger and the done card.
@MainActor
struct RecordScreen: View {
    @Environment(RecordModel.self) private var model
    @Environment(AppModel.self) private var app
    @State private var confirmNew = false

    var body: some View {
        ScreenScroll(title: "Record") {
            RoundHeader(confirmNew: $confirmNew)
            if model.session.phase == .setup {
                SetupForm()
            } else {
                if model.session.phase == .complete { DoneCard() }
                EntryPanel()
                VStack(alignment: .leading, spacing: BWMetrics.s2) {
                    BWSectionLabel("Scorecard")
                    ScoreStrip(round: model.round, current: model.session.index) { model.select($0) }
                }
                .bwCard()
                LedgerTable()
            }
        }
        .confirmationDialog("Start a new round?", isPresented: $confirmNew, titleVisibility: .visible) {
            Button("New round") { model.newRound() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This round stays saved in Rounds.")
        }
        .task(id: model.round.id) {
            app.weather.autoFill(model, enabled: app.settings.weatherAutoFill, network: app.network)
        }
    }
}

@MainActor
private struct RoundHeader: View {
    @Environment(RecordModel.self) private var model
    @Binding var confirmNew: Bool

    var body: some View {
        let r = model.round
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: BWMetrics.s1) {
                Text(r.sessionId.isEmpty ? "New round" : r.sessionId).bwDisplay(.title3)
                Text("\(r.date) · \(r.startTime) · Scheme \(r.scheme) · \(r.type)")
                    .font(BWFont.secondary).foregroundStyle(BW.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: BWMetrics.s1) {
                Text("\(r.score)").font(BWFont.valueLarge).foregroundStyle(BW.ink)
                Text("of \(r.recorded)").font(BWFont.note).foregroundStyle(BW.textMuted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Score \(r.score) of \(r.recorded) recorded")
        }
        .bwCard()
        HStack(spacing: BWMetrics.s2) {
            if model.session.phase != .setup {
                Button("Range data") { model.editSetup() }.buttonStyle(.bwSecondary)
            }
            Button("New round") { confirmNew = true }.buttonStyle(.bwSecondary).accessibilityIdentifier("record.newRound")
        }
    }
}

/// Range data and conditions. Everything is required before the first target, as in 7.0.7's `checkSetup`.
@MainActor
private struct SetupForm: View {
    @Environment(RecordModel.self) private var model
    @Environment(AppModel.self) private var app

    var body: some View {
        let r = model.round
        VStack(alignment: .leading, spacing: BWMetrics.s3) {
            BWSectionLabel("Range data")
            LabeledField("Range") {
                TextField("Range name", text: binding(\.place)).textInputAutocapitalization(.words)
            }
            HStack(spacing: BWMetrics.s3) {
                LabeledField("Field") {
                    Picker("Field", selection: Binding(get: { r.field ?? 0 }, set: { v in model.updateSetup { $0.field = v == 0 ? nil : v } })) {
                        Text("–").tag(0)
                        ForEach(1...12, id: \.self) { Text("\($0)").tag($0) }
                    }
                }
                LabeledField("First station") {
                    Picker("First station", selection: Binding(get: { r.startStation }, set: { v in model.updateSetup { $0.startStation = v } })) {
                        ForEach(1...Round.stationCount, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .disabled(model.session.startStationLocked)
                }
            }
            HStack(spacing: BWMetrics.s3) {
                LabeledField("Scheme") {
                    Picker("Scheme", selection: Binding(get: { r.scheme }, set: { v in model.updateSetup { $0.scheme = v } })) {
                        ForEach(Array(Schemes.numbers), id: \.self) { Text("\($0)").tag($0) }
                    }
                }
                LabeledField("Type") {
                    Picker("Type", selection: Binding(get: { r.type }, set: { v in model.updateSetup { $0.type = v } })) {
                        Text("Training").tag("Training"); Text("Competition").tag("Competition")
                    }
                }
            }

            BWSectionLabel("Conditions") {
                Button { app.weather.manualFill(model, network: app.network) } label: {
                    Label("Weather", systemImage: "location")
                }
                .font(BWFont.secondary.weight(.semibold))
                .disabled(app.weather.state == .fetching)
            }
            weatherLine
            HStack(spacing: BWMetrics.s3) {
                LabeledField("Sky") {
                    Picker("Sky", selection: binding(\.sky)) {
                        Text("–").tag("")
                        ForEach(Sky.allCases, id: \.self) { Text($0.name).tag($0.rawValue) }
                    }
                }
                LabeledField("Wind") {
                    Picker("Wind", selection: binding(\.wind)) {
                        Text("–").tag("")
                        ForEach(Wind.allCases, id: \.self) { Text($0.name).tag($0.rawValue) }
                    }
                }
            }
            HStack(spacing: BWMetrics.s3) {
                LabeledField("Temperature °C") {
                    NumberField(placeholder: "°C", value: r.temperature) { v in model.updateSetup { $0.temperature = v } }
                }
                LabeledField("Humidity %") {
                    NumberField(placeholder: "%", value: r.humidity) { v in model.updateSetup { $0.humidity = v } }
                }
            }
            LabeledField("Notes") {
                TextField("Notes", text: binding(\.notes), axis: .vertical).lineLimit(1...4)
            }
            MessageLine(error: model.error, note: nil)
            Button(model.session.hasStarted ? "Back to targets" : "Start round") { model.start() }
                .buttonStyle(.bwPrimary)
                .keyboardShortcut(BWKeys.save)
                .accessibilityIdentifier("record.start")
        }
        .bwCard()
    }

    @ViewBuilder private var weatherLine: some View {
        switch app.weather.state {
        case .idle: EmptyView()
        case .fetching: Text("Getting the weather…").font(BWFont.note).foregroundStyle(BW.textMuted)
        case .filled(let t): Text(t).font(BWFont.note).foregroundStyle(BW.textSecondary)
        case .failed(let t): Text(t).font(BWFont.note).foregroundStyle(BW.danger.foreground)
        }
    }

    private func binding(_ key: WritableKeyPath<Round, String>) -> Binding<String> {
        Binding(get: { model.round[keyPath: key] }, set: { v in model.updateSetup { $0[keyPath: key] = v } })
    }
}

/// A number typed as text. Keeps what the shooter types ("2." stays "2.") and hands the model a value only when it
/// parses; empty means no value. A comma is read as a decimal point.
@MainActor
struct NumberField: View {
    let placeholder: String
    let value: Double?
    let set: (Double?) -> Void
    @State private var text = ""

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .onAppear { text = value.map(JSText.number) ?? "" }
            .onChange(of: value) { _, v in if parsed != v { text = v.map(JSText.number) ?? "" } }
            .onChange(of: text) { _, _ in
                if text.trimmingCharacters(in: .whitespaces).isEmpty { if value != nil { set(nil) } }
                else if let d = parsed, d != value { set(d) }
            }
    }

    private var parsed: Double? {
        Double(text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }
}

/// Label above a control, the design system's form layout.
@MainActor
struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s1) {
            Text(label).bwLabel()
            content
                .frame(maxWidth: .infinity, minHeight: BWMetrics.actionHeight, alignment: .leading)
                .padding(.horizontal, BWMetrics.s3)
                .background(BW.paper, in: RoundedRectangle(cornerRadius: BWMetrics.radiusMD))
                .overlay(RoundedRectangle(cornerRadius: BWMetrics.radiusMD).stroke(BW.border, lineWidth: BWMetrics.hairline))
        }
        .frame(maxWidth: .infinity)
    }
}

/// The target on screen: station, machine, direction row, result row, NO TARGET, Skip, Time, Undo.
@MainActor
private struct EntryPanel: View {
    @Environment(RecordModel.self) private var model
    @Environment(\.breakpoint) private var breakpoint

    var body: some View {
        let r = model.round, i = model.session.index
        let odds = r.directionOdds(at: i)
        VStack(alignment: .leading, spacing: BWMetrics.s3) {
            HStack {
                Button { model.previous() } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.bwIcon).keyboardShortcut(BWKeys.previous).accessibilityLabel("Previous target")
                    .accessibilityIdentifier("record.previous")
                Spacer()
                VStack(spacing: 2) {
                    Text("Target \(i + 1) · Station \(r.station(at: i))").bwDisplay(.title3)
                    Text(machineText(r, i)).font(BWFont.secondary).foregroundStyle(BW.textSecondary)
                }
                Spacer()
                Button { model.next() } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.bwIcon).keyboardShortcut(BWKeys.next).accessibilityLabel("Next target")
                    .accessibilityIdentifier("record.next")
            }

            Text("Direction").bwLabel()
            HStack(spacing: BWMetrics.s2) {
                ForEach(Direction.displayOrder, id: \.self) { d in
                    let p = odds[d]
                    choice(title: "\(d.arrow) \(d.name)", sub: p > 0 ? JSText.fixed(p * 100, 0) + "%" : "full",
                           selected: r.directions[i] == d, status: BW.inkStatus, id: "record.direction.\(d.name.lowercased())") { model.record(direction: d) }
                        .keyboardShortcut(shortcut(d))
                        .disabled(p == 0 && r.directions[i] != d)
                }
            }
            Text("Result").bwLabel()
            HStack(spacing: BWMetrics.s2) {
                ForEach(TargetResult.allCases, id: \.self) { s in
                    choice(title: s.title, sub: s.rawValue, selected: r.results[i] == s, status: s.status, id: "record.result.\(identifier(s))") { model.record(result: s) }
                        .keyboardShortcut(shortcut(s))
                }
            }
            Button("NO TARGET") { model.noTarget() }
                .buttonStyle(BWSecondaryButtonStyle(height: 56))          // gloved hands (docs/app-store.md)
                .keyboardShortcut(BWKeys.noTarget)
                .accessibilityIdentifier("record.noTarget")
                .accessibilityHint("The clay did not come or came out broken. The target keeps its number.")
            HStack(spacing: BWMetrics.s2) {
                Button("Skip") { model.skip() }.buttonStyle(.bwSecondary)
                    .disabled(model.flow.slot(model.session) == nil)
                    .accessibilityIdentifier("record.skip")
                    .accessibilityHint("No time for this target.")
                Button("Time T\(i + 1)") { model.retime() }.buttonStyle(.bwSecondary)
                    .accessibilityIdentifier("record.retime")
                    .accessibilityHint("Clear this target's time and time it again.")
                Button("Undo") { model.undo() }.buttonStyle(.bwSecondary)
                    .disabled(!model.session.canUndo)
                    .keyboardShortcut(BWKeys.undo)
                    .accessibilityIdentifier("record.undo")
            }
            timingLine(r, i)
            MessageLine(error: model.error, note: model.message)
        }
        .bwCard()
        .sensoryFeedback(.impact(weight: .light), trigger: r.recorded)
    }

    private func machineText(_ r: Round, _ i: Int) -> String {
        let n = r.noTargetCount(at: i)
        let noTarget: String = n > 0 ? " · No target ×\(n)" : ""
        guard let m = r.machine(at: i) else { return "Scheme \(r.scheme)\(noTarget)" }
        let height: String = JSText.number(m.height)
        return "Trap \(m.number) · \(m.label) · \(height) m\(noTarget)"
    }

    private func timesText(_ first: Double, _ second: Double?) -> String {
        var text = "1st \(secondsText(first)) s"
        if let s = second { text += " · 2nd \(secondsText(s)) s" }
        return text
    }

    @ViewBuilder private func timingLine(_ r: Round, _ i: Int) -> some View {
        if let t = r.firstShot[i] {
            Text(timesText(t, r.secondShot[i]))
                .font(BWFont.value(.body)).foregroundStyle(BW.text)
        } else if model.session.skipped.contains(i) {
            Text("No time for this target.").font(BWFont.note).foregroundStyle(BW.textMuted)
        }
    }

    /// Identifiers follow `screen.element.name` (docs/testing.md) so the UI test can find every control.
    private func identifier(_ s: TargetResult) -> String {
        switch s { case .hitFirst: return "hitFirst"; case .hitSecond: return "hitSecond"; case .lost: return "lost" }
    }

    private func choice(title: String, sub: String, selected: Bool, status: BW.Status, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(BWFont.body.weight(.bold))
                Text(sub).font(BWFont.note)
            }
            .foregroundStyle(selected ? status.foreground : BW.text)
            .frame(maxWidth: .infinity, minHeight: breakpoint.minTouchTarget + BWMetrics.s4)
            .background(selected ? status.background : BW.paper, in: RoundedRectangle(cornerRadius: BWMetrics.radiusMD))
            .overlay(RoundedRectangle(cornerRadius: BWMetrics.radiusMD).stroke(selected ? status.border : BW.borderStrong, lineWidth: selected ? BWMetrics.rule : BWMetrics.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shortcut(_ d: Direction) -> KeyboardShortcut {
        switch d { case .left: return BWKeys.left; case .straight: return BWKeys.straight; case .right: return BWKeys.right }
    }
    private func shortcut(_ s: TargetResult) -> KeyboardShortcut {
        switch s { case .hitFirst: return BWKeys.hitFirst; case .hitSecond: return BWKeys.hitSecond; case .lost: return BWKeys.lost }
    }
}

/// Every target in a table: station, direction, result, times, break distance.
@MainActor
private struct LedgerTable: View {
    @Environment(RecordModel.self) private var model
    @Environment(AppModel.self) private var app

    var body: some View {
        let r = model.round
        let breakModel = BreakDistanceModel(settings: app.settings.breakDistance)
        VStack(alignment: .leading, spacing: 0) {
            BWSectionLabel("Targets").padding(.bottom, BWMetrics.s2)
            BWTableHeader(["#", "Stn", "Dir", "Res", "1st", "2nd", "Break"])
            ForEach(0..<Round.targetCount, id: \.self) { i in
                Button { model.select(i) } label: {
                    HStack {
                        cell("\(i + 1)"); cell("\(r.station(at: i))"); cell(r.directions[i]?.rawValue ?? "–")
                        cell(r.results[i]?.rawValue ?? "–", color: r.results[i]?.status.foreground)
                        cell(secondsText(r.firstShot[i])); cell(secondsText(r.secondShot[i]))
                        cell(r.breakDistance(at: i, model: breakModel).map { JSText.fixed($0, 1) + " m" } ?? "–")
                    }
                    .padding(.vertical, BWMetrics.s2)
                    .background(i == model.session.index ? BW.surfaceAlt : Color.clear)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("record.target.\(i + 1)")
                .accessibilityLabel("Target \(i + 1), station \(r.station(at: i)), \(r.directions[i]?.name ?? "no direction"), \(r.results[i]?.title ?? "no result")")
                .bwTableRow(index: i)
            }
        }
        .bwCard()
    }

    private func cell(_ t: String, color: Color? = nil) -> some View {
        Text(t).font(BWFont.value(.footnote, weight: .regular)).foregroundStyle(color ?? BW.text)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Shown when all 25 targets are in.
@MainActor
private struct DoneCard: View {
    @Environment(RecordModel.self) private var model
    var body: some View {
        let r = model.round, c = r.counts
        BWInkPanel {
            VStack(alignment: .leading, spacing: BWMetrics.s2) {
                Text("Round complete").font(BWFont.label).textCase(.uppercase).foregroundStyle(BW.onInk)
                Text("\(r.score) / 25").font(BWFont.readout(size: 48)).foregroundStyle(BW.onInk)
                Text("\(c.hitFirst) first barrel · \(c.hitSecond) second barrel · \(c.lost) lost")
                    .font(BWFont.secondary).foregroundStyle(BW.onInk)
                ShareRoundButton(round: r)
            }
            .padding(BWMetrics.s5)
        }
    }
}
