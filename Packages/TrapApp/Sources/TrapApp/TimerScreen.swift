import ShotTimer
import SwiftUI
import TrapCore
import TrapDesign
import TrapPlatform

/// Timer: Start/Stop, input, audio check line, the 0.000 readout, live level, rejected sounds, round audio.
@MainActor
struct TimerScreen: View {
    @Environment(RecordModel.self) private var model
    @Environment(AppModel.self) private var app

    var body: some View {
        let timer = model.timer
        ScreenScroll(title: "Timer") {
            if model.stoppedInBackground {
                MessageLine(error: DisplayError("Timing stopped when the app left the screen.", recovery: "Tap Start timer to go on."), note: nil)
                    .onTapGesture { model.acknowledgeBackgroundStop() }
            }
            if let advice = app.power.advice.message {
                Text(advice).font(BWFont.secondary).foregroundStyle(BW.warning.foreground)
                    .padding(BWMetrics.s3).frame(maxWidth: .infinity, alignment: .leading)
                    .background(BW.warning.background, in: RoundedRectangle(cornerRadius: BWMetrics.radiusMD))
            }
            Readout()
            mainButton(timer)
            Text(model.flow.status).font(BWFont.secondary).foregroundStyle(BW.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)
            MessageLine(error: model.error, note: timer.lastNote)

            VStack(alignment: .leading, spacing: BWMetrics.s3) {
                BWSectionLabel("Microphone")
                InputPicker()
                if timer.isRunning {
                    Text(timer.diagnostics.line)
                        .font(BWFont.value(.footnote, weight: .regular))
                        .foregroundStyle(timer.diagnostics.flowing ? BW.textSecondary : BW.danger.foreground)
                    LevelMeter(voice: timer.voiceDb, peak: timer.peakDb, callDb: timer.settings.callDb, shotDb: timer.settings.shotDb)
                }
                Toggle("Round audio", isOn: Binding(get: { app.settings.roundAudio }, set: { v in app.update { $0.roundAudio = v } }))
                    .disabled(timer.isRunning)
                if timer.lastRecordingURL != nil, let url = timer.recordingToShareIfPresent {
                    ShareLink(item: url) { Label("Share round audio", systemImage: "square.and.arrow.up") }
                }
            }
            .bwCard()

            if !model.rejected.isEmpty {
                VStack(alignment: .leading, spacing: BWMetrics.s2) {
                    BWSectionLabel("Not counted")
                    ForEach(model.rejected.keys.sorted { $0.rawValue < $1.rawValue }, id: \.self) { r in
                        BWField(r.text, value: "\(model.rejected[r] ?? 0)", mono: true)
                    }
                }
                .bwCard()
            }
        }
        .onChange(of: timer.isRunning, initial: true) { _, running in
            if running { ScreenAwake.shared.hold("timer") } else { ScreenAwake.shared.release("timer") }
        }
        .onAppear { if !timer.isRunning { timer.refreshInputs() } }
    }

    @ViewBuilder private func mainButton(_ timer: ShotTimerControlling) -> some View {
        if !timer.isRunning {
            Button("Start timer") {
                let id = app.settings.preferredInputID
                model.startTimer(input: timer.inputs.first { $0.id == id } ?? .systemDefault)
            }
            .buttonStyle(.bwPrimary)
            .keyboardShortcut(BWKeys.start)
            .disabled(model.session.phase == .setup)
            if model.session.phase == .setup {
                Text("Start the round on Record first.").font(BWFont.note).foregroundStyle(BW.textMuted)
            }
        } else {
            HStack(spacing: BWMetrics.s2) {
                if model.flow.phase == .idle {
                    Button("Arm T\(model.session.index + 1)") { model.armTapped() }
                        .buttonStyle(.bwPrimary).keyboardShortcut(BWKeys.start)
                }
                Button("Stop timer") { model.stopTimer() }.buttonStyle(.bwSecondary)
            }
        }
    }
}

/// The big call‑to‑shot figure.
@MainActor
private struct Readout: View {
    @Environment(RecordModel.self) private var model
    var body: some View {
        let first = model.readout?.first, second = model.readout?.second
        BWInkPanel {
            VStack(alignment: .leading, spacing: BWMetrics.s1) {
                Text(phaseText).font(BWFont.label).textCase(.uppercase).tracking(BWTracking.label).foregroundStyle(BW.onInk)
                Text(first.map { JSText.fixed($0, 3) } ?? "0.000")
                    .font(BWFont.readout())
                    .foregroundStyle(BW.onInk)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(second.map { "2nd " + JSText.fixed($0, 3) + " s" } ?? " ")
                    .font(BWFont.value(.title3)).foregroundStyle(BW.onInk)
            }
            .padding(BWMetrics.s5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(first.map { "First shot \(JSText.fixed($0, 3)) seconds" + (second.map { ", second \(JSText.fixed($0, 3))" } ?? "") } ?? "No time yet")
    }

    private var phaseText: String {
        switch model.flow.phase {
        case .off: return "Timer off"
        case .wait: return "Waiting for the round"
        case .idle: return "Ready to arm"
        case .armed: return "Listening"
        case .timing: return "Timing"
        case .entry: return "Enter result"
        case .review: return "Target complete"
        case .done: return "Round done"
        }
    }
}

/// Input choice: System default (DJI receiver first) or a specific input. Saved in settings.
@MainActor
private struct InputPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(RecordModel.self) private var model

    var body: some View {
        let timer = model.timer
        Picker("Input", selection: Binding(get: { app.settings.preferredInputID }, set: { v in app.update { $0.preferredInputID = v } })) {
            Text(timer.inputs.contains(where: \.isReferenceReceiver) ? "System default (\(ReferenceReceiver.name))" : "System default").tag("")
            ForEach(timer.inputs) { i in
                Text(i.isReferenceReceiver ? "\(ReferenceReceiver.name) receiver" : i.label).tag(i.id)
            }
        }
        .disabled(timer.isRunning)
        if timer.isRunning {
            Text("In use: " + (timer.route.isReferenceReceiver ? "\(ReferenceReceiver.name) receiver" : timer.route.label))
                .font(BWFont.note).foregroundStyle(BW.textSecondary)
        }
    }
}

/// Voice and peak level against the call and shot thresholds.
@MainActor
private struct LevelMeter: View {
    let voice: Double?
    let peak: Double?
    let callDb: Double
    let shotDb: Double

    var body: some View {
        VStack(alignment: .leading, spacing: BWMetrics.s1) {
            bar("Voice", voice, mark: callDb)
            bar("Peak", peak, mark: shotDb)
        }
    }

    private func bar(_ label: String, _ v: Double?, mark: Double) -> some View {
        let lo = 40.0, hi = 140.0
        let f = { (x: Double) in CGFloat(min(1, max(0, (x - lo) / (hi - lo)))) }
        return HStack(spacing: BWMetrics.s2) {
            Text(label).bwLabel().frame(width: 44, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(BW.surfaceAlt)
                    Rectangle().fill((v ?? 0) >= mark ? BW.ink : BW.grey400).frame(width: g.size.width * f(v ?? lo))
                    Rectangle().fill(BW.danger.dot).frame(width: 2).offset(x: g.size.width * f(mark))
                }
            }
            .frame(height: 10)
            Text(v.map { "\(Int($0)) dB" } ?? "–").font(BWFont.value(.caption, weight: .regular)).frame(width: 56, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) level " + (v.map { "\(Int($0)) decibels" } ?? "none"))
    }
}

private extension ShotTimerControlling {
    /// The last recording when its file still exists, without reporting an error.
    var recordingToShareIfPresent: URL? {
        guard let u = lastRecordingURL, FileManager.default.fileExists(atPath: u.path) else { return nil }
        return u
    }
}
