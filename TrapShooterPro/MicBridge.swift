import AVFoundation
import UIKit

/// Runs the shot timer natively and talks to the page's timer (window.__trapMic).
/// The page sends: start, stop, inputs, config, arm, disarm.
/// The app sends back: started, inputs, route, restarted, error, first, target, reject, level.
/// Rule: the audio session is set once, in start. Nothing re-applies it while timing runs.
final class MicBridge {
    private let detector = AudioDetector()
    private let recorder = RoundRecorder()
    private var lastRecording: URL?
    private var recordName = ""
    private var lastCfg: [String: Any] = [:]
    private let send: (String) -> Void
    private let present: (URL) -> Void
    private var running = false
    private var observers: [NSObjectProtocol] = []
    // watchdog: restarts the engine when no audio arrives
    private var watchdog: Timer?
    private var lastCount = -1
    private var stalledFor = 0.0
    private var flowingFor = 0.0
    private var restarts = 0
    private var reportedDead = false
    private var pendingRestart: DispatchWorkItem?

    init(send: @escaping (String) -> Void, present: @escaping (URL) -> Void) {
        self.send = send
        self.present = present
        detector.onFirstShot = { [weak self] ms in self?.call("first", ms) }
        detector.onTarget = { [weak self] t1, t2, db in
            let d: [String: Any] = [
                "t1": t1,
                "t2": t2.map { $0 as Any } ?? (NSNull() as Any),
                "callDb": db.map { $0 as Any } ?? (NSNull() as Any)
            ]
            self?.call("target", d)
        }
        detector.onReject = { [weak self] r in self?.call("reject", r.rawValue) }
        detector.onLevel = { [weak self] v, p in
            let d: [String: Any] = [
                "voiceDb": v.isFinite ? v as Any : NSNull() as Any,
                "peakDb": p.isFinite ? p as Any : NSNull() as Any
            ]
            self?.call("level", d)
        }
    }

    // MARK: messages from the page

    func handle(_ body: [String: Any]) {
        switch body["action"] as? String ?? "" {
        case "start":
            start(preferredInput: body["input"] as? String ?? "",
                  record: body["record"] as? Bool ?? false,
                  name: body["name"] as? String ?? "round")
        case "shareRecording":
            if let u = lastRecording, FileManager.default.fileExists(atPath: u.path) { present(u) }
            else { fail("No round audio saved yet. Turn on Round audio, then start and stop the timer.") }
        case "stop": stop()
        case "inputs": sendInputs()
        case "config": if let c = body["cfg"] as? [String: Any] { setConfig(c) }
        case "arm": if running { detector.arm(beep: body["beep"] as? Bool ?? false, once: body["once"] as? Bool ?? false) }
        case "disarm": detector.disarm()
        default: break
        }
    }

    private func setConfig(_ c: [String: Any]) {
        lastCfg = c
        func num(_ k: String, _ d: Double) -> Double { (c[k] as? NSNumber)?.doubleValue ?? d }
        var cfg = AudioDetector.Config()
        cfg.callDb = num("callDb", cfg.callDb)
        cfg.shotDb = num("shotDb", cfg.shotDb)
        cfg.echoMs = num("echoMs", cfg.echoMs)
        cfg.offset = num("offset", cfg.offset)
        cfg.minCallMs = num("minCallMs", cfg.minCallMs)
        cfg.secondWinMs = num("secondWinMs", cfg.secondWinMs)
        cfg.gateDb = (c["gateDb"] as? NSNumber)?.doubleValue
        detector.setConfig(cfg)
    }

    // MARK: start and stop

    private func start(preferredInput: String, record: Bool, name: String) {
        let granted: (Bool) -> Void = { [weak self] ok in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard ok else {
                    self.fail("Microphone access is off. Open Settings > Shooter Pro > Microphone and turn it on.")
                    return
                }
                do {
                    if self.running { self.detector.stop(); self.running = false }
                    try self.detector.start(preferredInput: preferredInput)
                    self.running = true
                    UIApplication.shared.isIdleTimerDisabled = true
                    self.observe()
                    var info = self.routeInfo()
                    info["sampleRate"] = self.detector.sr
                    self.recordName = name
                    if record, let file = self.beginRecording() { info["recording"] = file }
                    self.call("started", info)
                    self.sendInputs()
                    self.startWatchdog()
                } catch {
                    self.detector.stop()
                    self.fail("The microphone could not start (\(error.localizedDescription)).")
                }
            }
        }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission(completionHandler: granted)
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission(granted)
        }
    }

    func stop() {
        guard running else { return }
        running = false
        watchdog?.invalidate(); watchdog = nil
        pendingRestart?.cancel(); pendingRestart = nil
        detector.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        endRecording()
    }

    // MARK: round audio

    private func beginRecording() -> String? {
        let meta: [String: Any] = ["app": "TRAP SHOOTER PRO", "session": recordName,
                                   "mic": routeInfo()["label"] as? String ?? "", "timer": lastCfg]
        do {
            let url = try recorder.begin(name: recordName, sampleRate: detector.sr, meta: meta)
            detector.tap = { [weak self] buffer, ch in self?.recorder.append(buffer, channel: ch) }
            return url.lastPathComponent
        } catch {
            detector.tap = nil
            call("note", "Round audio could not start (\(error.localizedDescription)). Timing continues.")
            return nil
        }
    }

    private func endRecording() {
        detector.tap = nil
        guard recorder.isRecording else { return }
        recorder.finish { [weak self] url, seconds, mb in
            guard let self = self, let url = url else { return }
            self.lastRecording = url
            self.call("saved", ["name": url.lastPathComponent, "seconds": seconds, "mb": mb])
        }
    }

    // MARK: inputs and route

    /// Lists inputs without touching the audio session while timing runs.
    private func sendInputs() {
        let session = AVAudioSession.sharedInstance()
        if !running && session.category != .playAndRecord {
            try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        }
        let list: [[String: Any]] = (session.availableInputs ?? []).map {
            ["id": $0.uid, "label": $0.portName, "external": $0.portType != .builtInMic]
        }
        call("inputs", list)
    }

    private func routeInfo() -> [String: Any] {
        if let port = AVAudioSession.sharedInstance().currentRoute.inputs.first {
            return ["id": port.uid, "label": port.portName, "external": port.portType != .builtInMic]
        }
        return ["id": "", "label": "No input", "external": false]
    }

    private func observe() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // Only real plug and unplug events count. Category changes are ignored.
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.running,
                  let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  reason == .newDeviceAvailable || reason == .oldDeviceUnavailable else { return }
            self.call("route", self.routeInfo())
            self.sendInputs()
        })
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.running,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            self.stop()
            self.fail("Timing stopped by a call or alarm. Tap Start timer again.")
        })
        // The engine stops itself when the hardware changes (receiver plugged in, sample rate switch).
        // Wait for the route to settle, then build a fresh engine on it.
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            guard let self = self, self.running,
                  (note.object as AnyObject?) === (self.detector.engineForNotifications as AnyObject) else { return }
            self.scheduleRestart(after: 0.3, reason: "hardware change")
        })
    }

    // MARK: restart and watchdog

    private func scheduleRestart(after delay: Double, reason: String) {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restart(reason: reason) }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func restart(reason: String) {
        guard running else { return }
        do {
            let wasRecording = recorder.isRecording
            let oldRate = recorder.sampleRate
            try detector.rebuild()
            if wasRecording && oldRate != detector.sr {
                endRecording()
                _ = beginRecording()
            } else if wasRecording {
                detector.tap = { [weak self] buffer, ch in self?.recorder.append(buffer, channel: ch) }
            }
            var info = routeInfo()
            info["sampleRate"] = detector.sr
            info["reason"] = reason
            stalledFor = 0
            call("restarted", info)
        } catch {
            stop()
            fail("The microphone stopped (\(error.localizedDescription)). Tap Start timer again.")
        }
    }

    private func startWatchdog() {
        watchdog?.invalidate()
        lastCount = -1; stalledFor = 0; flowingFor = 0; restarts = 0; reportedDead = false
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func tick() {
        guard running else { return }
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
                let label = routeInfo()["label"] as? String ?? "the microphone"
                call("note", "No audio is arriving from \(label). Unplug and replug the receiver, check the transmitter is on, then Stop and Start timer.")
            }
        }
        let session = AVAudioSession.sharedInstance()
        let port = session.currentRoute.inputs.first
        let diag: [String: Any] = [
            "label": port?.portName ?? "No input",
            "type": port?.portType.rawValue ?? "",
            "hwRate": session.sampleRate,
            "rate": detector.sr,
            "channels": detector.inputChannels,
            "channel": detector.activeChannel + 1,
            "buffers": n,
            "flowing": stalledFor == 0 && n > 0,
            "restarts": restarts
        ]
        call("diag", diag)
    }

    // MARK: to the page

    private func fail(_ message: String) { call("error", message) }

    private func call(_ function: String, _ argument: Any) {
        guard let data = try? JSONSerialization.data(withJSONObject: [argument]),
              let json = String(data: data, encoding: .utf8) else { return }
        send("window.__trapMic && window.__trapMic.\(function)(\(json)[0])")
    }
}
