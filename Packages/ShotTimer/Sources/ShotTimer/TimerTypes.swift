import AVFoundation
import Foundation

/// Timer settings as the shooter sets them (Timer tab > Timer settings). Same keys as the 7.x page config.
public struct TimerSettings: Equatable, Codable, Sendable {
    /// Call threshold, dB.
    public var callDb: Double = 85
    /// Shot threshold, dB.
    public var shotDb: Double = 112
    /// Shortest gap between two shots, ms.
    public var echoMs: Double = 120
    /// dB SPL at digital full scale (calibration).
    public var offset: Double = 120
    /// Shortest call, ms.
    public var minCallMs: Double = 80
    /// Window for a 2nd shot after the 1st, ms.
    public var secondWinMs: Double = 1000
    /// Optional call gate: calls quieter than this are ignored.
    public var gateDb: Double?
    public init() {}

    var detectorConfig: AudioDetector.Config {
        var c = AudioDetector.Config()
        c.callDb = callDb; c.shotDb = shotDb; c.echoMs = echoMs; c.offset = offset
        c.minCallMs = minCallMs; c.secondWinMs = secondWinMs; c.gateDb = gateDb
        return c
    }
}

/// A microphone or receiver the session can use.
public struct AudioInput: Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    /// True for anything but the built‑in microphone (DJI, Lark, wired).
    public let isExternal: Bool
    public init(id: String, label: String, isExternal: Bool) { self.id = id; self.label = label; self.isExternal = isExternal }
    /// "System default": a plugged‑in receiver is preferred over the phone mic.
    public static let systemDefault = AudioInput(id: "", label: "System default", isExternal: false)
}

/// The input currently carrying audio.
public struct AudioRoute: Equatable, Sendable {
    public let id: String
    public let label: String
    public let isExternal: Bool
    public init(id: String, label: String, isExternal: Bool) { self.id = id; self.label = label; self.isExternal = isExternal }
    public static let noInput = AudioRoute(id: "", label: "No input", isExternal: false)
}

/// Why a sound was not counted.
public enum RejectReason: String, Sendable {
    case noCall = "nocall", click, quietCall = "quiet", loudVoice = "loudvoice"
    public var text: String {
        switch self {
        case .noCall: return "Shot with no call before it"
        case .click: return "Click, too short for a call"
        case .quietCall: return "Call quieter than your gate"
        case .loudVoice: return "Loud sound without shot character"
        }
    }
}

/// The audio check line on the Timer tab.
public struct AudioDiagnostics: Equatable, Sendable {
    public var label = "No input"
    public var portType = ""
    public var hardwareRate: Double = 0
    public var rate: Double = 0
    public var channels = 0
    public var activeChannel = 1
    public var buffers = 0
    public var flowing = false
    public var restarts = 0
    public init() {}
}

/// Result of one timed target.
public struct TimedTarget: Equatable, Sendable {
    /// Call to 1st shot, ms.
    public let firstMs: Double
    /// Call to 2nd shot, ms, when fired inside the window.
    public let secondMs: Double?
    /// Call peak, dB.
    public let callDb: Double?
    public init(firstMs: Double, secondMs: Double?, callDb: Double?) { self.firstMs = firstMs; self.secondMs = secondMs; self.callDb = callDb }
}

/// Everything the session reports, in the order the page received it from MicBridge.
public enum TimerEvent: Equatable, Sendable {
    case started(route: AudioRoute, sampleRate: Double, recording: String?)
    case inputs([AudioInput])
    case route(AudioRoute)
    case restarted(route: AudioRoute, sampleRate: Double, reason: String)
    case error(String)
    case note(String)
    case firstShot(ms: Double)
    case target(TimedTarget)
    case rejected(RejectReason)
    case level(voiceDb: Double?, peakDb: Double?)
    case diagnostics(AudioDiagnostics)
    case recordingSaved(name: String, seconds: Double, megabytes: Double)
}

/// Everything a screen needs from a shot timer. `TimerSession` is the real one; a scripted timer for previews and
/// UI tests conforms too, so no screen ever downcasts.
@MainActor
public protocol ShotTimerControlling: AnyObject {
    var isRunning: Bool { get }
    var isRecording: Bool { get }
    var inputs: [AudioInput] { get }
    var route: AudioRoute { get }
    var sampleRate: Double { get }
    var diagnostics: AudioDiagnostics { get }
    var voiceDb: Double? { get }
    var peakDb: Double? { get }
    var lastError: String? { get }
    var lastNote: String? { get }
    var lastRecordingURL: URL? { get }
    var settings: TimerSettings { get }
    /// Every event, in order.
    var onEvent: ((TimerEvent) -> Void)? { get set }
    func start(input: AudioInput, record: Bool, sessionName: String)
    func stop()
    func apply(_ settings: TimerSettings)
    func arm(beep: Bool, once: Bool)
    func disarm()
    func refreshInputs()
    func recordingToShare() -> URL?
}

/// The parts of `AudioDetector` the session uses. The real detector conforms by extension; tests inject a fake.
protocol ShotDetecting: AnyObject {
    var onFirstShot: ((Double) -> Void)? { get set }
    var onTarget: ((Double, Double?, Double?) -> Void)? { get set }
    var onReject: ((AudioDetector.Reject) -> Void)? { get set }
    var onLevel: ((Double, Double) -> Void)? { get set }
    var tap: ((AVAudioPCMBuffer, Int) -> Void)? { get set }
    var sr: Double { get }
    var inputChannels: Int { get }
    var activeChannel: Int { get }
    var engineForNotifications: AVAudioEngine { get }
    func setConfig(_ c: AudioDetector.Config)
    func start(preferredInput: String) throws
    func rebuild() throws
    func stop()
    func arm(beep: Bool, once: Bool)
    func disarm()
    func bufferCount() -> Int
}
extension AudioDetector: ShotDetecting {}

/// The parts of `RoundRecorder` the session uses.
protocol RoundRecording: AnyObject {
    var isRecording: Bool { get }
    var sampleRate: Double { get }
    func begin(name: String, sampleRate: Double, meta: [String: Any]) throws -> URL
    func append(_ buffer: AVAudioPCMBuffer, channel: Int)
    func finish(_ done: @escaping (URL?, Double, Double) -> Void)
}
extension RoundRecorder: RoundRecording {}
