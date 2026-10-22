import AVFoundation

/// Saves the microphone audio of a timing session as a compressed .m4a file (about 1 MB per minute),
/// with a small .json file holding the timer settings. Files live in Documents/Recordings, which shows
/// in the Files app under On My iPhone > TrapShoot. Writing happens on a background queue.
final class RoundRecorder {
    private let queue = DispatchQueue(label: "shooterpro.recorder")
    private var file: AVAudioFile?
    private var monoFormat: AVAudioFormat?
    private var frames: Int64 = 0
    private(set) var url: URL?
    private(set) var sampleRate: Double = 0
    var isRecording: Bool { url != nil }

    static var folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Recordings", isDirectory: true)
    }

    func begin(name: String, sampleRate sr: Double, meta: [String: Any]) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: RoundRecorder.folder, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression)
        let stamp = DateFormatter()
        stamp.dateFormat = "HHmmss"
        var target = RoundRecorder.folder.appendingPathComponent("shooterpro-\(safe.isEmpty ? "round" : safe)-\(stamp.string(from: Date())).m4a")
        var n = 2
        while fm.fileExists(atPath: target.path) {
            target = RoundRecorder.folder.appendingPathComponent("shooterpro-\(safe)-\(stamp.string(from: Date()))-\(n).m4a")
            n += 1
        }
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sr,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
        let f = try AVAudioFile(forWriting: target, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let mono = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sr, channels: 1, interleaved: false) else {
            throw NSError(domain: "TrapShooterPro", code: 2, userInfo: [NSLocalizedDescriptionKey: "Audio format not supported."])
        }
        var info = meta
        info["sampleRate"] = sr
        info["started"] = ISO8601DateFormatter().string(from: Date())
        if let json = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]) {
            try? json.write(to: target.deletingPathExtension().appendingPathExtension("json"))
        }
        queue.sync {
            file = f; monoFormat = mono; frames = 0
        }
        url = target
        sampleRate = sr
        return target
    }

    /// Called on the audio thread. Copies the channel in use and hands it to the writer queue.
    func append(_ buffer: AVAudioPCMBuffer, channel: Int = 0) {
        guard let fmt = monoFormat, let chans = buffer.floatChannelData,
              channel < Int(buffer.format.channelCount) else { return }
        let src = chans[channel]
        let n = buffer.frameLength
        guard n > 0, let copy = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: n),
              let dst = copy.floatChannelData?[0] else { return }
        copy.frameLength = n
        dst.update(from: src, count: Int(n))
        queue.async { [weak self] in
            guard let self = self, let f = self.file else { return }
            do { try f.write(from: copy); self.frames += Int64(n) } catch { /* keep timing even if the disk is full */ }
        }
    }

    /// Closes the file. done(url, seconds, megabytes) runs on the main queue.
    func finish(_ done: @escaping (URL?, Double, Double) -> Void) {
        let sr = sampleRate
        let finished = url
        url = nil
        queue.async { [weak self] in
            guard let self = self else { return }
            let fr = self.frames
            self.file = nil          // releasing the file finalizes it
            self.monoFormat = nil
            var mb = 0.0
            if let u = finished, let attrs = try? FileManager.default.attributesOfItem(atPath: u.path),
               let size = attrs[.size] as? NSNumber {
                mb = size.doubleValue / 1_048_576
            }
            let seconds = sr > 0 ? Double(fr) / sr : 0
            DispatchQueue.main.async { done(finished, seconds, mb) }
        }
    }
}
