import Foundation
import ShotTimer
import TrapCore
import TrapData

/// Demo mode (launch argument `-demo`): sample rounds in memory and a timer that never touches the microphone.
/// For screenshots in CI, previews and review; nothing is written to the real store.
enum DemoMode {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    @MainActor
    static func makeApp() -> AppModel {
        var settings = AppSettings()
        settings.profile.name = "Mohammad Tajudeen"
        settings.profile.weapon = "Perazzi MX8"
        settings.profile.ammo = "RC4 Champion 24 g 7.5"
        let rounds = sampleRounds()
        let defaults = UserDefaults(suiteName: "demo") ?? .standard
        defaults.removePersistentDomain(forName: "demo")
        defaults.set(rounds.last?.id, forKey: AppState.currentRoundKey)
        return AppModel(repository: InMemoryRoundRepository(rounds), timer: DemoTimer(), settings: settings, defaults: defaults)
    }

    /// 14 full rounds over the last weeks and one round in progress (12 of 25 targets), all obeying the station rule.
    static func sampleRounds(now: Date = Date()) -> [Round] {
        var rng = SeededRandom(seed: 20261022)
        var list: [Round] = []
        for k in 0..<15 {
            let day = now.addingTimeInterval(Double(k - 15) * 2 * 86_400)     // every other day, the last one today
            var r = Round.new(now: k == 14 ? now : day)
            r.id = "demo\(k)"
            r.startTime = k == 14 ? "09:30" : ["08:30", "09:00", "10:15", "16:40"][k % 4]
            r.shooter = "Mohammad Tajudeen"
            r.sessionId = SessionID.base(date: r.date, startTime: r.startTime, shooter: r.shooter)
            r.place = k % 3 == 0 ? "Al Ain Shooting Club" : "Abu Dhabi Shooting Club"
            r.field = 1 + k % 4
            r.scheme = k % 5 == 4 ? 7 : 2
            r.type = k % 6 == 5 ? "Competition" : "Training"
            r.startStation = 1 + k % 5
            r.sky = Sky.allCases[k % 4].rawValue
            r.wind = Wind.allCases[k % 3].rawValue
            r.temperature = Double(24 + k % 9)
            r.humidity = Double(35 + (k * 7) % 30)
            r.weapon = "Perazzi MX8"; r.ammo = "RC4 Champion 24 g 7.5"; r.choke1 = "3/4"; r.choke2 = "Full"
            // each station gets R, R, S, L, L in a shuffled order
            for s in 0..<Round.stationCount {
                let slots = (0..<Round.targetCount).filter { r.stationIndex(at: $0) == s }
                var dirs: [Direction] = [.right, .right, .straight, .left, .left]
                for i in stride(from: dirs.count - 1, to: 0, by: -1) { dirs.swapAt(i, rng.next(i + 1)) }
                for (n, i) in slots.enumerated() { r.directions[i] = dirs[n] }
            }
            let filled = k == 14 ? 12 : Round.targetCount
            let skill = 0.78 + Double(k) * 0.008
            for i in 0..<Round.targetCount {
                guard i < filled else { r.directions[i] = nil; continue }
                let hit = rng.unit() < skill, first = rng.unit() < 0.82
                r.results[i] = hit ? (first ? .hitFirst : .hitSecond) : .lost
                let t1 = 0.48 + rng.unit() * 0.24
                r.firstShot[i] = (t1 * 1000).rounded() / 1000
                if !(hit && first) { r.secondShot[i] = ((t1 + 0.28 + rng.unit() * 0.12) * 1000).rounded() / 1000 }
                r.callLevel[i] = (850 + rng.unit() * 100).rounded() / 10
                r.timerMic[i] = "DJI MIC MINI"
            }
            list.append(r)
        }
        return list
    }
}

/// Deterministic numbers so every screenshot run shows the same rounds.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func next(_ upper: Int) -> Int { min(upper - 1, Int(unit() * Double(upper))) }
}

/// A timer for demo mode: lists a DJI receiver and the phone mic, never starts the microphone.
/// With the extra launch argument `-uitest` it is the scripted timer of the UI tests (docs/testing.md): Start reports
/// a started route, and every arm is answered 0.4 s later with a first shot at 612 ms and a target at 612 / 1034 ms,
/// so the Record flow can be driven end to end in the simulator without audio.
@MainActor
final class DemoTimer: ShotTimerControlling {
    static var isScripted: Bool { ProcessInfo.processInfo.arguments.contains("-uitest") }
    var isRunning = false
    var isRecording = false
    var inputs = [AudioInput(id: "built-in", label: "iPhone Microphone", isExternal: false),
                  AudioInput(id: "usb-dji", label: "DJI MIC MINI", isExternal: true)]
    var route = AudioRoute.noInput
    var sampleRate: Double = 48_000
    var diagnostics = AudioDiagnostics()
    var voiceDb: Double?
    var peakDb: Double?
    var lastError: String?
    var lastNote: String?
    var lastRecordingURL: URL?
    var settings = TimerSettings()
    var onEvent: ((TimerEvent) -> Void)?
    func start(input: AudioInput, record: Bool, sessionName: String) {
        lastNote = "Demo mode: the microphone stays off."
        onEvent?(.note(lastNote ?? ""))
        guard DemoTimer.isScripted else { return }
        isRunning = true
        route = AudioRoute(id: "usb-dji", label: "DJI MIC MINI", isExternal: true)
        onEvent?(.started(route: route, sampleRate: sampleRate, recording: nil))
    }
    func stop() {
        isRunning = false
        armToken += 1
    }
    func apply(_ settings: TimerSettings) { self.settings = settings }

    private var armToken = 0
    func arm(beep: Bool, once: Bool) {
        guard DemoTimer.isScripted, isRunning else { return }
        armToken += 1
        let token = armToken
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, self.isRunning, token == self.armToken else { return }
            self.onEvent?(.firstShot(ms: 612))
            self.onEvent?(.target(TimedTarget(firstMs: 612, secondMs: 1034, callDb: 91)))
        }
    }
    func disarm() { armToken += 1 }
    func refreshInputs() {}
    func recordingToShare() -> URL? { nil }
}
