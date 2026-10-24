import AVFoundation
import XCTest
@testable import ShotTimer

/// The detector regression set (Phase 4): every fixture in `Tools/detector-fixtures/` is fed through `FileAnalyzer`
/// and must match its expected times within tolerance. With no fixtures recorded yet the real-recording test skips
/// with a reason; the synthetic tests below always run and prove the file path through the detector works.
final class DetectorRegressionTests: XCTestCase {

    // MARK: Real recordings

    func testEveryFixtureMatchesWithinTolerance() async throws {
        guard let folder = DetectorFixture.repositoryFolder else { throw XCTSkip("not in a checkout; Tools/detector-fixtures not found") }
        let fixtures = DetectorFixture.all(in: folder)
        if fixtures.isEmpty { throw XCTSkip("no fixtures in \(folder.path) yet; record them with /detector-fixtures (Tools/detector-fixtures/README.md)") }
        var failures: [String] = []
        for (fixture, audio) in fixtures {
            guard FileManager.default.fileExists(atPath: audio.path) else { failures.append("\(fixture.name): audio \(fixture.audio) missing"); continue }
            let result = try await FileAnalyzer.time(audio, settings: fixture.settings?.timerSettings ?? TimerSettings())
            for m in fixture.mismatches(against: result) { failures.append("\(fixture.name): \(m)") }
            print("fixture \(fixture.name): \(result.targets.count) targets, \(result.rejects.count) rejects, first shots \(result.firstMs.map { Int($0) })")
        }
        XCTAssertTrue(failures.isEmpty, "detector regression:\n" + failures.joined(separator: "\n"))
    }

    // MARK: Synthetic recordings (always run)

    /// A call (voice-band tone, 200 ms) followed by a shot (loud broadband burst) 600 ms later, then a 2nd shot
    /// 400 ms after the 1st, twice. The detector must report two targets near 600 / 1000 ms.
    func testSyntheticCallAndShotsAreTimed() async throws {
        let url = try Synth.write(targets: [(first: 0.600, second: 0.400), (first: 0.750, second: nil)])
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try await FileAnalyzer.time(url)
        XCTAssertEqual(result.targets.count, 2, "two targets in the file; got \(result.targets.map(\.firstMs))")
        guard result.targets.count == 2 else { return }
        XCTAssertEqual(result.targets[0].firstMs, 600, accuracy: 25, "1st target call to 1st shot")
        XCTAssertNotNil(result.targets[0].secondMs, "1st target has a 2nd shot")
        if let s = result.targets[0].secondMs { XCTAssertEqual(s, 1000, accuracy: 25, "1st target call to 2nd shot") }
        XCTAssertEqual(result.targets[1].firstMs, 750, accuracy: 25, "2nd target call to 1st shot")
        XCTAssertNil(result.targets[1].secondMs, "2nd target has one shot")
        XCTAssertEqual(result.sampleRate, 48_000)
    }

    func testFixtureComparison() {
        let fixture = DetectorFixture(name: "t", audio: "t.m4a", targets: [.init(firstMs: 600, secondMs: 1000), .init(firstMs: 750)])
        var result = FileAnalyzer.Result()
        result.targets = [TimedTarget(firstMs: 604, secondMs: 1003, callDb: 90), TimedTarget(firstMs: 761, secondMs: nil, callDb: 88)]
        let m = fixture.mismatches(against: result)
        XCTAssertEqual(m.count, 1)
        XCTAssertEqual(m.first?.target, 2)
        if case .first(let e, let g)? = m.first?.kind { XCTAssertEqual(e, 750); XCTAssertEqual(g, 761) } else { XCTFail("expected a 1st shot mismatch") }
        result.targets.removeLast()
        XCTAssertEqual(fixture.mismatches(against: result).map(\.description), ["target 2: expected but not detected"])
    }

    func testFixtureDecodesWithDefaults() throws {
        let json = """
        {"name":"n","audio":"a.m4a","targets":[{"firstMs":612,"secondMs":1034},{"firstMs":587,"secondMs":null}],"settings":{"shotDb":110}}
        """
        let f = try JSONDecoder().decode(DetectorFixture.self, from: Data(json.utf8))
        XCTAssertEqual(f.targets.count, 2)
        XCTAssertNil(f.toleranceMs)
        XCTAssertEqual(f.settings?.timerSettings.shotDb, 110)
        XCTAssertEqual(f.settings?.timerSettings.callDb, 85, "fields left out keep the app's defaults")
    }

    func testUnreadableFileThrows() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("not-audio-\(UUID().uuidString).m4a")
        try? Data("hello".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        do { _ = try await FileAnalyzer.time(url); XCTFail("expected an error") } catch let e as FileAnalyzer.Failure {
            XCTAssertEqual(e, .unreadable(url.lastPathComponent))
        } catch { XCTFail("unexpected \(error)") }
    }
}

/// Writes a mono 48 kHz CAF with a voice-band call and broadband shots at the given offsets. Levels are chosen
/// against the default thresholds (call 85 dB, shot 112 dB, offset 120 dB at full scale): call about 0.06 full
/// scale (95 dB), shot about 0.9 (119 dB), background noise about 0.0005 (54 dB).
private enum Synth {
    static func write(targets: [(first: Double, second: Double?)]) throws -> URL {
        let sr = 48_000.0
        var samples: [Float] = []
        var rng = SystemRandomNumberGenerator()
        func noise(_ seconds: Double) { for _ in 0..<Int(seconds * sr) { samples.append(Float.random(in: -0.0005...0.0005, using: &rng)) } }
        func call(_ seconds: Double) {
            let n = Int(seconds * sr)
            for i in 0..<n {
                let t = Double(i) / sr
                let env = min(1, Double(i) / (0.01 * sr)) * min(1, Double(n - i) / (0.01 * sr))
                // three voice-band partials, like a short "pull"
                let v = 0.06 * env * (sin(2 * .pi * 220 * t) + 0.6 * sin(2 * .pi * 440 * t) + 0.4 * sin(2 * .pi * 660 * t)) / 2
                samples.append(Float(v) + Float.random(in: -0.0005...0.0005, using: &rng))
            }
        }
        func shot() {
            // 30 ms burst: 10 ms at full level, then an exponential tail; broadband so > 5 % of the energy is above 3 kHz
            let n = Int(0.030 * sr)
            for i in 0..<n {
                let env = i < Int(0.010 * sr) ? 1.0 : exp(-Double(i - Int(0.010 * sr)) / (0.006 * sr))
                samples.append(Float(0.9 * env) * Float.random(in: -1...1, using: &rng))
            }
        }
        noise(1.0)                                                 // let the background floor settle
        for t in targets {
            let callLen = 0.200
            call(callLen)
            noise(t.first - callLen)                               // first is measured from the call onset
            shot()
            if let s = t.second { noise(s - 0.030); shot() }
            noise(2.5)                                             // longer than the 2nd shot window; next target
        }
        // The file is 16-bit interleaved WAV (what a file on disk must be); the buffer is the engine's float32
        // non-interleaved format and AVAudioFile converts on write. A standard format's own `settings` describe a
        // non-interleaved stream, which AVAudioFile refuses as a file layout ("nilError").
        let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let fileSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sr, AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synthetic-\(UUID().uuidString).wav")
        do {
            let file = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            let chunk = 4096
            var offset = 0
            while offset < samples.count {
                let n = min(chunk, samples.count - offset)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n))!
                buffer.frameLength = AVAudioFrameCount(n)
                samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress! + offset, count: n) }
                try file.write(from: buffer)
                offset += n
            }
        }                                                          // the writer closes when it goes out of scope
        return url
    }
}
