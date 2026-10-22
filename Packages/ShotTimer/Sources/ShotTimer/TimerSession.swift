import AVFoundation
import Observation

/// The shot timer as the app sees it. A port of 7.0.7's `MicBridge`: it starts and stops the microphone,
/// restarts it after hardware changes or silence, records round audio, and publishes results.
/// Rule kept from the original: the audio session is set once, in start. Nothing re-applies it while timing runs.
/// All state changes happen on the main actor; the detector delivers its callbacks on the main queue.
/// Keeping the screen awake is the app's job (`TrapPlatform.ScreenAwake`), driven by `isRunning`.
@MainActor
@Observable
public final class TimerSession: ShotTimerControlling {
    // MARK: observable state
    public private(set) var isRunning = false
    public private(set) var inputs: [AudioInput] = []
    public private(set) var route: AudioRoute = .noInput
    public private(set) var sampleRate: Double = 0
    public private(set) var diagnostics = AudioDiagnostics()
    public private(set) var voiceDb: Double?
    public private(set) var peakDb: Double?
    public private(set) var lastError: String?
    public private(set) var lastNote: String?
    public private(set) var isRecording = false
    public private(set) var lastRecordingURL: URL?
    public private(set) var settings = TimerSettings()
    /// Every event, in order. Screens that need more than the state above subscribe here.
    @ObservationIgnored public var onEvent: ((TimerEvent) -> Void)?

    // MARK: private
    private let detector: ShotDetecting
    private let recorder: RoundRecording
    @ObservationIgnored private var recordName = ""
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    // watchdog: restarts the engine when no audio arrives
    @ObservationIgnored private var watchdog: Timer?
    @ObservationIgnored private var lastCount = -1
    @ObservationIgnored private var stalledFor = 0.0
    @ObservationIgnored private var flowingFor = 0.0
    @ObservationIgnored private var restarts = 0
    @ObservationIgnored private var reportedDead = false
    @ObservationIgnored private var pendingRestart: DispatchWorkItem?

    public convenience init() { self.init(detector: AudioDetector(), recorder: RoundRecorder()) }

    /// Tests inject fakes here.
    init(detector: ShotDetecting, recorder: RoundRecording) {
        self.detector = detector
        self.recorder = recorder
        detector.onFirstShot = { [weak self] ms in
            MainActor.assumeIsolated { self?.emit(.firstShot(ms: ms)) }
        }
        detector.onTarget = { [weak self] t1, t2, db in
            MainActor.assumeIsolated { self?.emit(.target(TimedTarget(firstMs: t1, secondMs: t2, callDb: db))) }
        }
        detector.onReject = { [weak self] r in
            MainActor.assumeIsolated { self?.emit(.rejected(RejectReason(rawValue: r.rawValue) ?? .noCall)) }
        }
        detector.onLevel = { [weak self] v, p in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.voiceDb = v.isFinite ? v : nil
                self.peakDb = p.isFinite ? p : nil
                self.emit(.level(voiceDb: self.voiceDb, peakDb: self.peakDb))
            }
        }
    }

    deinit {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        watchdog?.invalidate()
        pendingRestart?.cancel()
    }

    // MARK: control

    public func apply(_ s: TimerSettings) {
        settings = s
        detector.setConfig(s.detectorConfig)
    }

    public func arm(beep: Bool, once: Bool) {
        guard isRunning else { return }
        detector.arm(beep: beep, once: once)
    }

    public func disarm() { detector.disarm() }

    /// The last round audio file, for a share sheet. Nil when none was saved.
    public func recordingToShare() -> URL? {
        guard let u = lastRecordingURL, FileManager.default.fileExists(atPath: u.path) else {
            fail("No round audio saved yet. Turn on Round audio, then start and stop the timer.")
            return nil
        }
        return u
    }

    public func start(input: AudioInput = .systemDefault, record: Bool = false, sessionName: String = "round") {
        AVAudioApplication.requestRecordPermission { [weak self] ok in
            Task { @MainActor [weak self] in self?.begin(granted: ok, preferredInput: input.id, record: record, name: sessionName) }
        }
    }

    private func begin(granted: Bool, preferredInput: String, record: Bool, name: String) {
        guard granted else {
            fail("Microphone access is off. Open Settings > TrapShoot > Microphone and turn it on.")
            return
        }
        if isRunning { stop() }                       // closes an open recording and cancels a pending restart
        do {
            try detector.start(preferredInput: preferredInput)
            isRunning = true
            lastError = nil
            observe()
            route = routeInfo()
            sampleRate = detector.sr
            recordName = name
            var recording: String?
            if record { recording = beginRecording() }
            emit(.started(route: route, sampleRate: sampleRate, recording: recording))
            refreshInputs()
            startWatchdog()
        } catch {
            detector.stop()
            removeObservers()
            fail("The microphone could not start (\(error.localizedDescription)).")
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        watchdog?.invalidate(); watchdog = nil
        pendingRestart?.cancel(); pendingRestart = nil
        detector.stop()
        removeObservers()
        endRecording()
    }

    // MARK: round audio

    private func installTap() {
        let rec = recorder                                   // the tap runs on the audio render thread
        detector.tap = { @Sendable buffer, ch in rec.append(buffer, channel: ch) }
    }

    private func beginRecording() -> String? {
        let meta: [String: Any] = ["app": "TrapShooterPro", "session": recordName, "mic": route.label,
                                   "timer": ["callDb": settings.callDb, "shotDb": settings.shotDb, "echoMs": settings.echoMs, "offset": settings.offset,
                                             "minCallMs": settings.minCallMs, "secondWinMs": settings.secondWinMs, "gateDb": settings.gateDb.map { $0 as Any } ?? NSNull()]]
        do {
            let url = try recorder.begin(name: recordName, sampleRate: detector.sr, meta: meta)
            installTap()
            isRecording = true
            return url.lastPathComponent
        } catch {
            detector.tap = nil
            note("Round audio could not start (\(error.localizedDescription)). Timing continues.")
            return nil
        }
    }

    private func endRecording() {
        detector.tap = nil
        guard recorder.isRecording else { return }
        isRecording = false
        recorder.finish { [weak self] url, seconds, mb in
            MainActor.assumeIsolated {
                guard let self, let url else { return }
                self.lastRecordingURL = url
                self.emit(.recordingSaved(name: url.lastPathComponent, seconds: seconds, megabytes: mb))
            }
        }
    }

    // MARK: inputs and route

    /// Lists inputs without touching the audio session while timing runs.
    public func refreshInputs() {
        let session = AVAudioSession.sharedInstance()
        if !isRunning && session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        }
        inputs = (session.availableInputs ?? []).map { AudioInput(id: $0.uid, label: $0.portName, isExternal: $0.portType != .builtInMic) }
        emit(.inputs(inputs))
    }

    private func routeInfo() -> AudioRoute {
        if let port = AVAudioSession.sharedInstance().currentRoute.inputs.first {
            return AudioRoute(id: port.uid, label: port.portName, isExternal: port.portType != .builtInMic)
        }
        return .noInput
    }

    private func observe() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Only real plug and unplug events count. Category changes are ignored.
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, self.isRunning, let raw, let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                      reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
                self.route = self.routeInfo()
                self.emit(.route(self.route))
                self.refreshInputs()
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, self.isRunning, let raw, AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                self.stop()
                self.fail("Timing stopped by a call or alarm. Tap Start timer again.")
            }
        })
        // The engine stops itself when the hardware changes (receiver plugged in, sample rate switch).
        // Wait for the route to settle, then build a fresh engine on it.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            let object = note.object as AnyObject?
            MainActor.assumeIsolated {
                guard let self, self.isRunning, object === (self.detector.engineForNotifications as AnyObject) else { return }
                self.scheduleRestart(after: 0.3, reason: "hardware change")
            }
        })
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers = []
    }

    // MARK: restart and watchdog

    private func scheduleRestart(after delay: Double, reason: String) {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.restart(reason: reason) }
        }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restart(reason: String) {
        guard isRunning else { return }
        do {
            let wasRecording = recorder.isRecording
            let oldRate = recorder.sampleRate
            try detector.rebuild()
            if wasRecording && oldRate != detector.sr {
                endRecording()
                _ = beginRecording()
            } else if wasRecording {
                installTap()
            }
            route = routeInfo()
            sampleRate = detector.sr
            stalledFor = 0
            emit(.restarted(route: route, sampleRate: sampleRate, reason: reason))
        } catch {
            stop()
            fail("The microphone stopped (\(error.localizedDescription)). Tap Start timer again.")
        }
    }

    private func startWatchdog() {
        watchdog?.invalidate()
        lastCount = -1; stalledFor = 0; flowingFor = 0; restarts = 0; reportedDead = false
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard isRunning else { return }
        let n = detector.bufferCount()
        if n == lastCount { stalledFor += 0.5; flowingFor = 0 } else { lastCount = n; stalledFor = 0; flowingFor += 0.5 }
        if flowingFor >= 5 { restarts = 0; reportedDead = false }
        if stalledFor >= 1.5 {
            if restarts < 3 {
                restarts += 1
                stalledFor = 0
                restart(reason: "no audio, restart \(restarts) of 3")
            } else if !reportedDead {
                reportedDead = true
                note("No audio is arriving from \(route.label.isEmpty ? "the microphone" : route.label). Unplug and replug the receiver, check the transmitter is on, then Stop and Start timer.")
            }
        }
        let session = AVAudioSession.sharedInstance()
        let port = session.currentRoute.inputs.first
        var d = AudioDiagnostics()
        d.label = port?.portName ?? "No input"
        d.portType = port?.portType.rawValue ?? ""
        d.hardwareRate = session.sampleRate
        d.rate = detector.sr
        d.channels = detector.inputChannels
        d.activeChannel = detector.activeChannel + 1
        d.buffers = n
        d.flowing = stalledFor == 0 && n > 0
        d.restarts = restarts
        diagnostics = d
        emit(.diagnostics(d))
    }

    // MARK: events

    private func fail(_ message: String) { lastError = message; emit(.error(message)) }
    private func note(_ message: String) { lastNote = message; emit(.note(message)) }
    private func emit(_ e: TimerEvent) { onEvent?(e) }
}
