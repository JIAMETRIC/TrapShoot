import AVFoundation

/// Times Olympic Trap call-to-shot intervals from the microphone.
/// Same detector as the Trap Shot Timer app (v2), which runs on the athlete's iPhone.
///
/// Rules:
///  1. Each shot is anchored to the LAST valid call before it (look-back), so a gun-closing
///     click or any sound before the real call never starts the timer.
///  2. A valid call is voice-band energy (about 150 to 1,500 Hz) lasting >= minCallMs.
///     Metallic clicks are short and mostly high-pitched, so they fail.
///  3. A shot with no valid call 0.15 to 2.0 s before it (the next shooter) is ignored.
///  4. Optional call gate: calls quieter than the athlete's median call minus a margin are ignored.
///  5. A 2nd shot only counts inside secondWinMs after the 1st (gun opening falls outside it).
///  6. A shot is confirmed over its first 5 ms: RMS at least a quarter of the shot threshold AND at least 5% of
///     its energy above 3 kHz. Gunshots carry 20 to 60% there, voices under 1%. (v3, validated on 9 range videos)
///  7. Within 0.6 s of a shot, a new shot must come at least 0.2 s later and rise 14 dB over the sound just
///     before it. This rejects the first shot's echo tail as a false 2nd shot.
///  8. The call onset is traced back to 6 dB over the background level, which removes a threshold-dependent bias.
/// Start and stop come from the same input stream, measured in samples, so device latency cancels out.
/// Detection runs on the audio thread. Only results go to the web page.
final class AudioDetector {
    struct Config {
        var callDb: Double = 85
        var shotDb: Double = 112
        var echoMs: Double = 120
        var offset: Double = 120        // dB SPL at digital full scale (calibration)
        var minCallMs: Double = 80
        var secondWinMs: Double = 1000
        var minRtMs: Double = 150
        var maxRtMs: Double = 2000
        var gateDb: Double? = nil
        var clickRatio: Double = 0.2
    }

    enum Reject: String { case noCall = "nocall", click = "click", quietCall = "quiet", loudVoice = "loudvoice" }

    // Callbacks, always delivered on the main queue.
    var onFirstShot: ((Double) -> Void)?
    var onTarget: ((_ t1: Double, _ t2: Double?, _ callDb: Double?) -> Void)?
    var onReject: ((Reject) -> Void)?
    var onLevel: ((_ voiceDb: Double, _ peakDb: Double) -> Void)?
    /// Optional: receives every input buffer and the channel in use, on the audio thread (round audio recording).
    var tap: ((AVAudioPCMBuffer, Int) -> Void)?

    private struct Run { var onset: Int64; var len = 0; var eV = 0.0; var eB = 0.0; var peakV = 0.0; var below = 0 }
    private struct Cand { var onset: Int64; var db: Double }
    private struct Pending { var idx: Int64; var sum = 0.0; var sumH = 0.0; var k = 0; var a: Double; var pk: Double; var prev: Double }
    private struct Open { var start: Int64; var s1: Int64; var callDb: Double }

    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    // input health, read by the bridge's watchdog
    private var buffersIn = 0
    private(set) var inputChannels = 0
    private(set) var activeChannel = 0
    private var chEnergy: [Double] = []
    private let lock = NSLock()
    private var beepBuffer: AVAudioPCMBuffer?

    private var cfg = Config()
    private(set) var sr: Double = 48_000

    // filter and running windows
    private var b0 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
    // 3 kHz high-pass for the shot test
    private var hb0 = 0.0, hb1 = 0.0, hb2 = 0.0, ha1 = 0.0, ha2 = 0.0
    private var hx1 = 0.0, hx2 = 0.0, hy1 = 0.0, hy2 = 0.0
    private var floorV = -1.0
    private var W = 480
    private var ringV: [Double] = [], ringB: [Double] = []
    private var ri = 0, sumV = 0.0, sumB = 0.0
    private var H = 4800
    private var hist: [Double] = []
    private var medBuf: [Double] = []
    private var hi = 0

    // detection state
    private var n: Int64 = 0
    private var run: Run?
    private var cands: [Cand] = []
    private var pend: Pending?
    private var open: Open?
    private var callLockUntil: Int64 = 0
    private var lastShot: Int64 = Int64.min / 2
    private var ignoreUntil: Int64 = 0
    private var armed = false
    private var firstPolicy = false      // beep mode: earliest sound after the beep is the start
    private var disarmAfter = false
    private var armToken = 0
    private var posts: [() -> Void] = []

    private var peakB = 0.0, peakV = 0.0
    private var lastLevelPost: Int64 = 0

    var isRunning: Bool { engine.isRunning }
    var engineForNotifications: AVAudioEngine { engine }

    func setConfig(_ c: Config) { lock.lock(); cfg = c; lock.unlock() }

    // MARK: Start / stop

    /// Sets the audio session once, then starts the engine.
    func start(preferredInput: String) throws {
        let session = AVAudioSession.sharedInstance()
        // .measurement turns off automatic gain and voice processing.
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setPreferredSampleRate(48_000)
        try? session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        if !preferredInput.isEmpty, let port = session.availableInputs?.first(where: { $0.uid == preferredInput }) {
            try? session.setPreferredInput(port)
        } else if let external = session.availableInputs?.first(where: { $0.portType != .builtInMic }) {
            // System default: use a plugged-in receiver (DJI, Lark) over the phone mic
            try? session.setPreferredInput(external)
        } else {
            try? session.setPreferredInput(nil)
        }
        try startEngine()
    }

    /// Starts (or restarts) the engine on the current route. The session is left as it is.
    func startEngine() throws {
        if engine.isRunning { engine.stop() }
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let inFormat = input.outputFormat(forBus: 0)
        guard inFormat.sampleRate > 0, inFormat.channelCount > 0 else {
            throw NSError(domain: "TrapShooterPro", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone input found."])
        }

        lock.lock()
        setup(sampleRate: inFormat.sampleRate)
        armed = false
        armToken += 1
        inputChannels = Int(inFormat.channelCount)
        activeChannel = 0
        chEnergy = Array(repeating: 0, count: inputChannels)
        lock.unlock()

        let outFormat = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        if player.engine == nil { engine.attach(player) }
        engine.connect(player, to: engine.mainMixerNode, format: outFormat)
        beepBuffer = makeBeep(format: outFormat)

        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buffer, when in
            self?.process(buffer, when)
        }
        engine.prepare()
        try engine.start()
    }

    /// Throws away the engine and builds a new one on the current route.
    /// Used after a hardware change (receiver plugged in, sample rate switch) or when no audio arrives.
    func rebuild() throws {
        engine.inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        try startEngine()
    }

    /// Number of input buffers received so far (the watchdog checks that it keeps rising).
    func bufferCount() -> Int { lock.lock(); defer { lock.unlock() }; return buffersIn }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        lock.lock(); armed = false; armToken += 1; lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Median of the onset history (0.3 s of 10 ms voice-band RMS). Runs once per call start; no allocation.
    private func medHist() -> Double {
        for i in 0..<H { medBuf[i] = hist[i] }
        medBuf.sort()
        return medBuf[H >> 1]
    }

    // Internal (not private) so FileAnalyzer can feed a recording through the same code path. Phase 4, task 2:
    // the only edit ever made to this file; no detection logic changed.
    func setup(sampleRate: Double) {
        sr = sampleRate
        W = max(1, Int(sr * 0.010))
        ringV = Array(repeating: 0, count: W); ringB = Array(repeating: 0, count: W)
        ri = 0; sumV = 0; sumB = 0
        H = max(3, Int(sr * 0.3)); hist = Array(repeating: 0, count: H); medBuf = Array(repeating: 0, count: H); hi = 0
        // RBJ band-pass, centre 550 Hz, Q 0.6
        let w0 = 2 * Double.pi * 550 / sr, alpha = sin(w0) / (2 * 0.6), a0 = 1 + alpha
        b0 = alpha / a0; b2 = -alpha / a0; a1 = -2 * cos(w0) / a0; a2 = (1 - alpha) / a0
        x1 = 0; x2 = 0; y1 = 0; y2 = 0
        // RBJ high-pass 3 kHz, Q 0.707
        let hw0 = 2 * Double.pi * min(3000, sr * 0.45) / sr, hal = sin(hw0) / (2 * 0.7071), ha0 = 1 + hal, hc = cos(hw0)
        hb0 = (1 + hc) / 2 / ha0; hb1 = -(1 + hc) / ha0; hb2 = (1 + hc) / 2 / ha0; ha1 = -2 * hc / ha0; ha2 = (1 - hal) / ha0
        hx1 = 0; hx2 = 0; hy1 = 0; hy2 = 0; floorV = -1
        n = 0; run = nil; cands = []; pend = nil; open = nil
        callLockUntil = 0; lastShot = Int64.min / 2; ignoreUntil = 0
        peakB = 0; peakV = 0; lastLevelPost = 0
    }

    // MARK: Arming

    /// once: disarm after one target (tap mode). beep: play a beep after 1.5 to 3.5 s and time from it.
    func arm(beep: Bool, once: Bool) {
        lock.lock()
        armToken += 1
        let token = armToken
        armed = !beep
        cands = []; run = nil; open = nil
        firstPolicy = beep
        disarmAfter = once || beep
        ignoreUntil = 0
        lock.unlock()

        if beep {
            let delay = Double.random(in: 1.5...3.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.fireBeep(token: token)
            }
        }
    }

    func disarm() {
        lock.lock()
        armToken += 1
        armed = false; cands = []; run = nil; open = nil
        lock.unlock()
    }

    private func fireBeep(token: Int) {
        lock.lock()
        guard token == armToken, engine.isRunning else { lock.unlock(); return }
        armed = true
        cands = []; run = nil; open = nil
        ignoreUntil = n            // the beep reaches the mic after this point
        lock.unlock()
        guard let buf = beepBuffer else { return }
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private func makeBeep(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * 0.30)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let ch = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames
        let ramp = max(1, Int(format.sampleRate * 0.002))
        for i in 0..<Int(frames) {
            let phase = Double(i) * 1000.0 / format.sampleRate
            let square: Float = phase.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : -1
            var env: Float = 1
            if i < ramp { env = Float(i) / Float(ramp) }
            if i > Int(frames) - ramp { env = Float(Int(frames) - i) / Float(ramp) }
            ch[i] = 0.9 * square * env
        }
        return buf
    }

    // MARK: Detection (lock held)

    private func lin(_ db: Double) -> Double { min(pow(10, (db - cfg.offset) / 20), 0.995) }
    private func toDb(_ l: Double) -> Double { l > 0 ? 20 * log10(l) + cfg.offset : -Double.infinity }
    private func post(_ f: @escaping () -> Void) { posts.append(f) }

    private func endRun(force: Bool) {
        guard let r = run else { return }
        run = nil
        let dur = r.len - r.below
        let ratio = r.eB > 0 ? r.eV / r.eB : 0
        let minLen = Int(cfg.minCallMs / 1000 * sr)
        let okShape = firstPolicy || ratio >= cfg.clickRatio
        if dur >= minLen && okShape {
            let db = toDb(r.peakV)
            if let g = cfg.gateDb, !firstPolicy, db < g {
                let cb = onReject; post { cb?(.quietCall) }
                return
            }
            cands.append(Cand(onset: r.onset, db: db))
        } else if !force {
            let cb = onReject; post { cb?(.click) }
        }
    }

    private func finalize(s2: Int64?) {
        guard let o = open else { return }
        open = nil
        let t1 = Double(o.s1 - o.start) / sr * 1000
        let t2 = s2.map { Double($0 - o.start) / sr * 1000 }
        let db: Double? = o.callDb.isFinite ? o.callDb : nil
        let cb = onTarget
        post { cb?(t1, t2, db) }
        if disarmAfter { armed = false }
    }

    private func handleShot(idx: Int64) {
        lastShot = idx
        if let r = run, r.len >= Int(cfg.minCallMs / 1000 * sr) { endRun(force: true) } else { run = nil }
        callLockUntil = idx + Int64(0.25 * sr)
        if armed {
            if open != nil {
                finalize(s2: idx)
            } else {
                let minRT = Int64(cfg.minRtMs / 1000 * sr), maxRT = Int64(cfg.maxRtMs / 1000 * sr)
                var best: Cand?
                for c in cands {
                    let dt = idx - c.onset
                    guard dt >= minRT, dt <= maxRT, c.onset >= ignoreUntil else { continue }
                    if let b = best {
                        if firstPolicy ? c.onset < b.onset : c.onset > b.onset { best = c }
                    } else { best = c }
                }
                if let b = best {
                    open = Open(start: b.onset, s1: idx, callDb: b.db)
                    let ms = Double(idx - b.onset) / sr * 1000
                    let cb = onFirstShot; post { cb?(ms) }
                } else {
                    let cb = onReject; post { cb?(.noCall) }
                }
            }
        }
        cands = []
    }

    func process(_ buffer: AVAudioPCMBuffer, _ when: AVAudioTime) {
        guard let chans = buffer.floatChannelData else { return }
        let count = Int(buffer.frameLength)
        let nch = Int(buffer.format.channelCount)

        lock.lock()
        buffersIn += 1
        // A receiver can deliver 2 channels with the transmitter on only one. Follow the channel that
        // carries sound: switch when another channel is 10 dB stronger over about 1 s.
        if nch > 1 && count > 0 {
            if chEnergy.count != nch { chEnergy = Array(repeating: 0, count: nch); activeChannel = 0 }
            for c in 0..<nch {
                var e = 0.0
                let p = chans[c]
                var i = 0
                while i < count { let v = Double(p[i]); e += v * v; i += 8 }
                chEnergy[c] += (e / Double((count + 7) / 8) - chEnergy[c]) * 0.05
            }
            if let best = chEnergy.indices.max(by: { chEnergy[$0] < chEnergy[$1] }),
               best != activeChannel, chEnergy[best] > chEnergy[activeChannel] * 10 {
                activeChannel = best
            }
        } else { activeChannel = 0 }
        let useCh = min(activeChannel, max(nch - 1, 0))
        lock.unlock()

        tap?(buffer, useCh)
        let ch = chans[useCh]

        lock.lock()
        let callL = lin(cfg.callDb), shotL = lin(cfg.shotDb), lowL = callL * 0.25
        let echo = Int64(cfg.echoMs / 1000 * sr)
        let secWin = Int64(cfg.secondWinMs / 1000 * sr)
        let maxRT = Int64(cfg.maxRtMs / 1000 * sr)
        let confirmN = max(1, Int(0.005 * sr))
        let below20 = Int(0.02 * sr), maxRun = Int(1.5 * sr)
        let tailN = Int64(0.6 * sr), minSplitN = Int64(0.2 * sr), riseMin = pow(10, 14.0 / 20)
        let floorFast = 1 / (0.05 * sr), floorSlow = 1 / (3 * sr), settleN = Int64(0.5 * sr)
        let Wd = Double(W)

        for i in 0..<count {
            let v = Double(ch[i])
            let a = abs(v)
            let idx = n

            let y = b0 * v + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = v; y2 = y1; y1 = y
            let h = hb0 * v + hb1 * hx1 + hb2 * hx2 - ha1 * hy1 - ha2 * hy2
            hx2 = hx1; hx1 = v; hy2 = hy1; hy1 = h
            let prevB = (max(sumB, 0) / Wd).squareRoot()
            let vb = v * v, yv = y * y
            sumB += vb - ringB[ri]; ringB[ri] = vb
            sumV += yv - ringV[ri]; ringV[ri] = yv
            ri = (ri + 1) % W
            let rmsV = (max(sumV, 0) / Wd).squareRoot()
            hist[hi] = rmsV; hi = (hi + 1) % H
            // background level: follows drops at once, rises over about 3 s (fast during the first 0.5 s)
            if floorV < 0 || rmsV < floorV { floorV = rmsV } else { floorV += (rmsV - floorV) * (idx < settleN ? floorFast : floorSlow) }
            if a > peakB { peakB = a }
            if rmsV > peakV { peakV = rmsV }

            if let o = open, idx - o.s1 > secWin { finalize(s2: nil) }

            // Shot: sudden rise from a quieter background that stays loud for 5 ms.
            if pend == nil, a >= shotL, prevB < shotL * 0.5, idx - lastShot > echo {
                pend = Pending(idx: idx, a: a, pk: a, prev: prevB)
            }
            var shotNow = false
            if var p = pend {
                p.sum += vb; p.sumH += h * h; p.k += 1
                if a > p.pk { p.pk = a }
                if p.k >= confirmN {
                    pend = nil
                    let inTail = p.idx - lastShot < tailN
                    let tailOk = !inTail || (p.idx - lastShot >= minSplitN && p.pk >= p.prev * riseMin)
                    if (p.sum / Double(p.k)).squareRoot() >= shotL * 0.25 && p.sumH >= p.sum * 0.05 && tailOk {
                        handleShot(idx: p.idx); shotNow = true
                    } else {
                        let cb = onReject; post { cb?(.loudVoice) }
                    }
                } else { pend = p }
            }

            if !shotNow, idx >= callLockUntil, idx >= ignoreUntil {
                if rmsV >= callL {
                    if run == nil {
                        // Back-track to where the voice level first rose.
                        // v3.1 (rule M): stop 6 dB above the typical background of the last 0.3 s (its median),
                        // not only 6 dB above the quietest dips, so ordinary noise before the call is not counted as call.
                        var j = 1
                        let backL = min(lowL, max(floorV * 2, medHist() * 2, callL * 0.01))
                        while j < H - 1 && hist[(hi - 1 - j + H) % H] >= backL { j += 1 }
                        run = Run(onset: max(idx - Int64(j) + 1, callLockUntil))
                    }
                    run!.below = 0
                }
                if var r = run {
                    r.len += 1
                    if pend == nil { r.eV += yv; r.eB += vb }
                    if rmsV > r.peakV { r.peakV = rmsV }
                    if rmsV < callL * 0.5 { r.below += 1 }
                    run = r
                    if r.below > below20 { endRun(force: false) }
                    else if r.len > maxRun { run = nil }
                }
            }
            if let first = cands.first, idx - first.onset > maxRT {
                cands.removeAll { idx - $0.onset > maxRT }
            }
            n += 1
        }

        if n - lastLevelPost > Int64(0.05 * sr) {
            let vDb = toDb(peakV), pDb = toDb(peakB)
            peakV = 0; peakB = 0; lastLevelPost = n
            let cb = onLevel
            post { cb?(vDb, pDb) }
        }
        let out = posts
        posts = []
        lock.unlock()

        if !out.isEmpty {
            DispatchQueue.main.async { out.forEach { $0() } }
        }
    }
}
