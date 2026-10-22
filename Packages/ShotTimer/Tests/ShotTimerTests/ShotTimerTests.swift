import AVFoundation
import XCTest
@testable import ShotTimer

/// A detector that does nothing with audio; the test fires its callbacks.
final class FakeDetector: ShotDetecting {
    var onFirstShot: ((Double) -> Void)?
    var onTarget: ((Double, Double?, Double?) -> Void)?
    var onReject: ((AudioDetector.Reject) -> Void)?
    var onLevel: ((Double, Double) -> Void)?
    var tap: ((AVAudioPCMBuffer, Int) -> Void)?
    var sr: Double = 48_000
    var inputChannels = 1
    var activeChannel = 0
    let engineForNotifications = AVAudioEngine()
    var config = AudioDetector.Config()
    var started = 0, stopped = 0, rebuilt = 0, armed: [(Bool, Bool)] = [], buffers = 0
    var failStart = false
    func setConfig(_ c: AudioDetector.Config) { config = c }
    func start(preferredInput: String) throws { if failStart { throw NSError(domain: "t", code: 1) }; started += 1 }
    func rebuild() throws { rebuilt += 1 }
    func stop() { stopped += 1 }
    func arm(beep: Bool, once: Bool) { armed.append((beep, once)) }
    func disarm() {}
    func bufferCount() -> Int { buffers }
}

final class FakeRecorder: RoundRecording {
    var isRecording = false
    var sampleRate: Double = 0
    var begun = 0, finished = 0
    func begin(name: String, sampleRate: Double, meta: [String: Any]) throws -> URL {
        isRecording = true; self.sampleRate = sampleRate; begun += 1
        return URL(fileURLWithPath: "/tmp/\(name).m4a")
    }
    func append(_ buffer: AVAudioPCMBuffer, channel: Int) {}
    func finish(_ done: @escaping (URL?, Double, Double) -> Void) {
        isRecording = false; finished += 1
        done(URL(fileURLWithPath: "/tmp/round.m4a"), 12, 0.2)
    }
}

@MainActor
final class ShotTimerTests: XCTestCase {
    func testSettingsMapToDetectorConfig() {
        var s = TimerSettings(); s.callDb = 80; s.shotDb = 110; s.gateDb = 70
        let c = s.detectorConfig
        XCTAssertEqual(c.callDb, 80); XCTAssertEqual(c.shotDb, 110); XCTAssertEqual(c.gateDb, 70); XCTAssertEqual(c.minRtMs, 150)
        XCTAssertEqual(RejectReason(rawValue: AudioDetector.Reject.loudVoice.rawValue), .loudVoice)
        XCTAssertEqual(AudioInput.systemDefault.id, "")
    }

    func testEventsFlowFromDetectorCallbacks() {
        let det = FakeDetector(), rec = FakeRecorder()
        let session = TimerSession(detector: det, recorder: rec)
        var events: [TimerEvent] = []
        session.onEvent = { events.append($0) }
        det.onFirstShot?(612.5)
        det.onTarget?(612.5, 1034.0, 91.2)
        det.onReject?(.click)
        det.onLevel?(88, 101)
        XCTAssertEqual(events, [.firstShot(ms: 612.5), .target(TimedTarget(firstMs: 612.5, secondMs: 1034.0, callDb: 91.2)), .rejected(.click), .level(voiceDb: 88, peakDb: 101)])
        XCTAssertEqual(session.voiceDb, 88)
        session.apply({ var s = TimerSettings(); s.echoMs = 90; return s }())
        XCTAssertEqual(det.config.echoMs, 90)
        XCTAssertFalse(session.isRunning)
        session.arm(beep: false, once: true)
        XCTAssertTrue(det.armed.isEmpty, "arming is ignored while not running")
    }

    func testRecordingToShareWithoutFile() {
        let session = TimerSession(detector: FakeDetector(), recorder: FakeRecorder())
        var events: [TimerEvent] = []
        session.onEvent = { events.append($0) }
        XCTAssertNil(session.recordingToShare())
        XCTAssertEqual(events.count, 1)
        XCTAssertNotNil(session.lastError)
    }
}
