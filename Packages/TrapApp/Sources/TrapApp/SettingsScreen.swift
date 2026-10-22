import ShotTimer
import SwiftUI
import TrapCore
import TrapData
import TrapDesign
import TrapPlatform
import TrapReports
import UniformTypeIdentifiers

/// Settings: profile, new-round defaults, timer, break distance, weather and reminders; Data (storage, recordings,
/// backup, restore, export); About (version, diagnostics, the hidden debug screen).
@MainActor
struct SettingsScreen: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            ProfileSection()
            NewRoundSection()
            TimerSection()
            BreakSection()
            Section("Weather and reminders") {
                Toggle("Fill weather automatically", isOn: setting(\.weatherAutoFill))
                Text("Once per round, before the first target, never on Low Data Mode. The values stay editable.")
                    .font(BWFont.note).foregroundStyle(BW.textMuted)
                Toggle("Remind me of an unfinished round", isOn: setting(\.unfinishedReminder))
                Text("A quiet reminder 20 minutes after you leave a round unfinished. Permission is asked the first time.")
                    .font(BWFont.note).foregroundStyle(BW.textMuted)
            }
            DataSection()
            AboutSection()
        }
        .scrollContentBackground(.hidden)
        .background(BW.surface)
        .navigationTitle("Settings")
    }

    private func setting<V>(_ key: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(get: { app.settings[keyPath: key] }, set: { v in app.update { $0[keyPath: key] = v } })
    }
}

/// `app.settings` as a binding, for the sections below.
@MainActor
private struct SettingBinding {
    let app: AppModel
    func callAsFunction<V>(_ key: WritableKeyPath<AppSettings, V>) -> Binding<V> {
        Binding(get: { app.settings[keyPath: key] }, set: { v in app.update { $0[keyPath: key] = v } })
    }
}

@MainActor
private struct ProfileSection: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let s = SettingBinding(app: app)
        Section {
            TextField("Name", text: s(\.profile.name)).textContentType(.name)
            TextField("Date of birth (yyyy-mm-dd)", text: s(\.profile.dateOfBirth)).keyboardType(.numbersAndPunctuation)
            TextField("Gun", text: s(\.profile.weapon))
            TextField("Ammunition", text: s(\.profile.ammo))
            TextField("Choke 1", text: s(\.profile.choke1))
            TextField("Choke 2", text: s(\.profile.choke2))
        } header: { Text("Shooter") } footer: {
            Text("Your initials end every session id. Gun, ammunition and chokes fill new rounds.")
        }
    }
}

@MainActor
private struct NewRoundSection: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let s = SettingBinding(app: app)
        Section("New rounds") {
            Picker("Scheme", selection: s(\.defaultScheme)) {
                ForEach(Array(Schemes.numbers), id: \.self) { Text("Scheme \($0)").tag($0) }
            }
            Picker("Type", selection: s(\.defaultType)) {
                Text("Training").tag("Training"); Text("Competition").tag("Competition")
            }
        }
    }
}

@MainActor
private struct TimerSection: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let s = SettingBinding(app: app)
        Section {
            Picker("Start signal", selection: s(\.timing.startSignal)) {
                Text("Voice call").tag(TimingPreferences.StartSignal.voice)
                Text("Beep").tag(TimingPreferences.StartSignal.beep)
            }
            Picker("Arming", selection: s(\.timing.arming)) {
                Text("Automatic").tag(TimingPreferences.Arming.auto)
                Text("Tap to arm").tag(TimingPreferences.Arming.tap)
            }
            stepper("Call threshold", s(\.timer.callDb), 50...110, 1, "dB")
            stepper("Shot threshold", s(\.timer.shotDb), 90...140, 1, "dB")
            stepper("Echo gap", s(\.timer.echoMs), 50...400, 10, "ms")
            stepper("Shortest call", s(\.timer.minCallMs), 30...300, 10, "ms")
            stepper("2nd shot window", s(\.timer.secondWinMs), 400...2000, 50, "ms")
            stepper("Calibration", s(\.timer.offset), 90...140, 1, "dB at full scale")
            Toggle("Call gate", isOn: Binding(get: { app.settings.timer.gateDb != nil },
                                              set: { on in app.update { $0.timer.gateDb = on ? ($0.timer.gateDb ?? 70) : nil } }))
            if app.settings.timer.gateDb != nil {
                stepper("Gate", Binding(get: { app.settings.timer.gateDb ?? 70 }, set: { v in app.update { $0.timer.gateDb = v } }), 40...110, 1, "dB")
            }
            Button("Reset timer settings") { app.update { $0.timer = TimerSettings(); $0.timing = TimingPreferences() } }
        } header: { Text("Shot timer") } footer: {
            Text("Tuned with the \(ReferenceReceiver.name). Change one value at a time and check on the range.")
        }
    }

    private func stepper(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ step: Double, _ unit: String) -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text(JSText.number(value.wrappedValue) + " " + unit).font(BWFont.value(.body, weight: .regular)).foregroundStyle(BW.textSecondary)
            }
        }
    }
}

@MainActor
private struct BreakSection: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let s = SettingBinding(app: app)
        Section {
            Toggle("Show break distance", isOn: s(\.breakDistance.enabled))
            Stepper("Release delay \(JSText.number(app.settings.breakDistance.releaseDelayMs)) ms", value: s(\.breakDistance.releaseDelayMs), in: 0...200, step: 5)
            Stepper("Clay speed \(JSText.number(app.settings.breakDistance.claySpeed)) m/s", value: s(\.breakDistance.claySpeed), in: 20...40, step: 0.5)
            Stepper("Shot speed \(JSText.number(app.settings.breakDistance.shotSpeed)) m/s", value: s(\.breakDistance.shotSpeed), in: 330...500, step: 5)
            Picker("Shot size", selection: s(\.breakDistance.shotSize)) {
                ForEach(ShotSize.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        } header: { Text("Break distance") } footer: {
            Text("Estimated from the shot time, the trap angle and these speeds.")
        }
    }
}

/// Storage report, recordings, backup, restore and CSV export.
@MainActor
private struct DataSection: View {
    @Environment(AppModel.self) private var app
    @State private var report = StorageReport.measure()
    @State private var recordings: [Recording] = []
    @State private var importing = false
    @State private var importResult: String?
    @State private var importFailed = false

    var body: some View {
        Section {
            LabeledContent("Rounds store", value: StorageReport.text(report.storeBytes))
            LabeledContent("Round audio", value: "\(report.recordingsCount) files · " + StorageReport.text(report.recordingsBytes))
            if let free = report.freeBytes { LabeledContent("Free on this iPhone", value: StorageReport.text(free)) }
            if report.lowOnSpace {
                Text("Space is low. Delete old round audio or move it to Files.").font(BWFont.note).foregroundStyle(BW.warning.foreground)
            }
            if !recordings.isEmpty {
                Button("Delete round audio older than 30 days") {
                    _ = RecordingsStore().deleteOlder(than: 30)
                    refresh()
                }
            }
            ShareRoundsButton(title: "Back up all rounds", format: .json) { try app.repository.fetchAll() }
            ShareRoundsButton(title: "Export all rounds as CSV", format: .csv) { try app.repository.fetchAll() }
            Button("Restore or import a backup") { importing = true }
            if let r = importResult {
                Text(r).font(BWFont.note).foregroundStyle(importFailed ? BW.danger.foreground : BW.textSecondary)
            }
        } header: { Text("Data") } footer: {
            Text("Everything stays on this iPhone. A backup is one file you keep in Files or iCloud Drive. Importing never replaces a round you already have.")
        }
        .onAppear { refresh() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            switch result {
            case .success(let url): importBackup(url)
            case .failure: importFailed = true; importResult = "The file could not be opened."
            }
        }
    }

    private func refresh() {
        report = StorageReport.measure()
        recordings = RecordingsStore().list()
    }

    /// Validate at the boundary (CLAUDE.md rule 12): size limit, tolerant decode, sanitise, then report.
    private func importBackup(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            guard size <= 50 * 1_048_576 else { importFailed = true; importResult = "That file is larger than any backup (over 50 MB)."; return }
            let rounds = try Backup.decode(Data(contentsOf: url))
            guard !rounds.isEmpty else { importFailed = true; importResult = "No rounds found in that file."; return }
            let r = try TrapLog.measure("import") { try Importer.merge(rounds, into: app.repository, policy: .skipExisting) }
            importFailed = false
            importResult = r.summary
            TrapLog.data.info("import: \(r.added, privacy: .public) added, \(r.skipped, privacy: .public) skipped")
            app.libraryChanged()
            refresh()
        } catch {
            importFailed = true
            importResult = DisplayError(any: error, fallback: "That file is not a TrapShooterPro backup or round export.").text
        }
    }
}

/// Version, channel, diagnostics. A long press on the version opens the debug screen (docs/debugging.md).
@MainActor
private struct AboutSection: View {
    @Environment(AppModel.self) private var app
    @State private var bundle: SharedFile?
    @State private var problem: String?
    @State private var showDebug = false

    var body: some View {
        Section("About") {
            LabeledContent(AppInfo.displayName, value: AppInfo.versionLine + " · " + AppInfo.channel)
                .onLongPressGesture { showDebug = true }
            Button("Send diagnostics") {
                do {
                    bundle = SharedFile(url: try SupportBundle.make(audioLine: app.timer.diagnostics.line,
                                                                     extra: ["Network": app.network.interface, "Power": app.power.advice.message ?? "normal"]))
                    problem = nil
                } catch { problem = "The diagnostics file could not be made." }
            }
            if let p = problem { Text(p).font(BWFont.note).foregroundStyle(BW.danger.foreground) }
            Text("No account, no server, no analytics. Diagnostics hold app and device facts and recent log lines, never your rounds, and leave the phone only if you send them.")
                .font(BWFont.note).foregroundStyle(BW.textMuted)
        }
        .sheet(item: $bundle) { ActivitySheet(file: $0) }
        .sheet(isPresented: $showDebug) { DebugScreen() }
    }
}

/// Hidden debug screen: audio check line, network, power, store and the last hour of log lines.
@MainActor
private struct DebugScreen: View {
    @Environment(AppModel.self) private var app
    @State private var lines: [String] = []
    var body: some View {
        NavigationStack {
            List {
                Section("Now") {
                    Text(app.timer.diagnostics.line).font(BWFont.value(.footnote, weight: .regular))
                    LabeledContent("Network", value: app.network.interface + (app.network.isConstrained ? " (Low Data)" : ""))
                    LabeledContent("Power", value: app.power.advice.message ?? "normal")
                    LabeledContent("Store", value: app.storeProblem == nil ? "open" : "in memory")
                }
                Section("Log, last 60 minutes") {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                        Text(l).font(BWFont.value(.caption2, weight: .regular))
                    }
                }
            }
            .navigationTitle("Debug")
            .task { lines = TrapLog.recentEntries(minutes: 60) }
        }
    }
}
