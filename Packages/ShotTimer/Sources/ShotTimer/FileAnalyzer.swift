import AVFoundation

/// "Time a recording": feeds an audio file through the same `AudioDetector` the live timer uses, with the same
/// settings, armed for every target the way the range flow arms after each result. Nothing about detection is
/// different from the microphone path except where the samples come from, so a recording with known call and
/// shot times is a regression test of the detector (Phase 4, `DetectorFixture`).
public enum FileAnalyzer {
    /// Everything the detector reported for one file, in order.
    public struct Result: Equatable, Sendable {
        /// Each timed target: call to 1st shot, optional 2nd shot, call level.
        public var targets: [TimedTarget] = []
        /// Sounds the detector rejected (clicks, calls without shots, quiet calls, loud voices).
        public var rejects: [RejectReason] = []
        /// Call to 1st shot of every target, ms. Convenience for comparisons.
        public var firstMs: [Double] { targets.map(\.firstMs) }
        /// Length of the recording, seconds.
        public var seconds: Double = 0
        /// Sample rate the file was decoded at.
        public var sampleRate: Double = 0
        public init() {}
    }

    public enum Failure: Error, Equatable {
        /// The file could not be opened as audio.
        case unreadable(String)
        /// The file has no frames.
        case empty
        /// Decoding stopped part way; the text names the file, the frame and the system error.
        case readFailed(String)
    }

    /// Times `url`. Runs the detector synchronously on the calling task, then waits for its main-queue callbacks.
    /// - Parameters:
    ///   - url: a `.m4a`, `.wav`, `.caf` or `.mp4` the system can decode.
    ///   - settings: the timer settings to use; the defaults are the app's.
    public static func time(_ url: URL, settings: TimerSettings = TimerSettings()) async throws -> Result {
        let file: AVAudioFile
        do { file = try AVAudioFile(forReading: url) } catch { throw Failure.unreadable(url.lastPathComponent) }
        let format = file.processingFormat                       // float32, deinterleaved, the engine's format
        guard file.length > 0 else { throw Failure.empty }

        let detector = AudioDetector()
        detector.setConfig(settings.detectorConfig)
        let sink = Sink()
        detector.onTarget = { t1, t2, db in sink.add(target: TimedTarget(firstMs: t1, secondMs: t2, callDb: db)) }
        detector.onReject = { r in if let reason = RejectReason(rawValue: r.rawValue) { sink.add(reject: reason) } }
        detector.setup(sampleRate: format.sampleRate)
        detector.arm(beep: false, once: false)                   // stay armed: every target in the file counts

        let frames: AVAudioFrameCount = 1024                       // the engine's tap size
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { throw Failure.unreadable(url.lastPathComponent) }
        var position: AVAudioFramePosition = 0
        // Never ask for more frames than remain: AVAudioFile.read(into:frameCount:) can throw at the end of the file.
        while position < file.length {
            let want = AVAudioFrameCount(min(AVAudioFramePosition(frames), file.length - position))
            do { try file.read(into: buffer, frameCount: want) } catch { throw Failure.readFailed("\(url.lastPathComponent) at frame \(position): \(error)") }
            if buffer.frameLength == 0 { break }
            detector.process(buffer, AVAudioTime(sampleTime: position, atRate: format.sampleRate))
            position += AVAudioFramePosition(buffer.frameLength)
        }
        // A 2nd shot window still open at the end of the file closes only when more samples arrive; feed silence
        // for the window plus a margin so the last target is reported.
        let tail = AVAudioFrameCount((settings.secondWinMs / 1000 + 0.2) * format.sampleRate)
        if let silence = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: tail) {
            silence.frameLength = tail
            for c in 0..<Int(format.channelCount) { silence.floatChannelData?[c].update(repeating: 0, count: Int(tail)) }
            detector.process(silence, AVAudioTime(sampleTime: position, atRate: format.sampleRate))
        }

        // The detector posts its callbacks with DispatchQueue.main.async; a block queued now runs after all of them.
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in DispatchQueue.main.async { c.resume() } }
        var result = Result()
        (result.targets, result.rejects) = sink.snapshot()
        result.seconds = Double(file.length) / format.sampleRate
        result.sampleRate = format.sampleRate
        return result
    }

    /// Collects the detector's callbacks (delivered on the main queue) behind a lock, so no actor isolation is
    /// needed in the callback closures.
    private final class Sink: @unchecked Sendable {
        private let lock = NSLock()
        private var targets: [TimedTarget] = []
        private var rejects: [RejectReason] = []
        func add(target: TimedTarget) { lock.lock(); targets.append(target); lock.unlock() }
        func add(reject: RejectReason) { lock.lock(); rejects.append(reject); lock.unlock() }
        func snapshot() -> ([TimedTarget], [RejectReason]) { lock.lock(); defer { lock.unlock() }; return (targets, rejects) }
    }
}
