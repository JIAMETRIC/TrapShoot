import Foundation
import ShotTimer
import TrapCore
import TrapPlatform

/// Everything the shooter sets once and keeps: profile, timer, break distance, weather, reminders.
/// One Codable value in UserDefaults (`CodableDefaults`); a new field gets a default, so old values still load.
public struct AppSettings: Equatable, Codable, Sendable {
    public struct Profile: Equatable, Codable, Sendable {
        public var name = ""
        public var dateOfBirth = ""
        public var weapon = ""
        public var ammo = ""
        public var choke1 = ""
        public var choke2 = ""
        public init() {}
    }

    public var profile = Profile()
    public var timer = TimerSettings()
    public var timing = TimingPreferences()
    public var breakDistance = BreakSettings()
    /// Scheme for new rounds.
    public var defaultScheme = Schemes.defaultScheme
    /// Round type for new rounds ("Training" or "Competition").
    public var defaultType = "Training"
    /// Fill the conditions from the weather service when a round is opened (never on Low Data Mode).
    public var weatherAutoFill = true
    /// The quiet reminder for a round left unfinished (ADR-011).
    public var unfinishedReminder = true
    /// Record round audio while timing (off by default when the battery is low).
    public var roundAudio = false
    /// The input the shooter picked; "" is System default (DJI receiver first).
    public var preferredInputID = ""

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile) ?? d.profile
        timer = try c.decodeIfPresent(TimerSettings.self, forKey: .timer) ?? d.timer
        timing = try c.decodeIfPresent(TimingPreferences.self, forKey: .timing) ?? d.timing
        breakDistance = try c.decodeIfPresent(BreakSettings.self, forKey: .breakDistance) ?? d.breakDistance
        defaultScheme = try c.decodeIfPresent(Int.self, forKey: .defaultScheme) ?? d.defaultScheme
        defaultType = try c.decodeIfPresent(String.self, forKey: .defaultType) ?? d.defaultType
        weatherAutoFill = try c.decodeIfPresent(Bool.self, forKey: .weatherAutoFill) ?? d.weatherAutoFill
        unfinishedReminder = try c.decodeIfPresent(Bool.self, forKey: .unfinishedReminder) ?? d.unfinishedReminder
        roundAudio = try c.decodeIfPresent(Bool.self, forKey: .roundAudio) ?? d.roundAudio
        preferredInputID = try c.decodeIfPresent(String.self, forKey: .preferredInputID) ?? d.preferredInputID
    }

    static let store = CodableDefaults(key: "settings.v1", fallback: AppSettings())
}

/// Small values that survive a relaunch: the round being recorded and the selected section.
enum AppState {
    static let currentRoundKey = "state.currentRoundID"
    static let sectionKey = "state.section"
}
