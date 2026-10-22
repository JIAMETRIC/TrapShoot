import Foundation

/// One round of 25 targets. A value type that mirrors the web app's round object one to one,
/// so the document v2 JSON used by the 7.x web app and its Supabase table round-trips without loss.
public struct Round: Equatable, Sendable {
    public static let targetCount = 25
    public static let stationCount = 5

    public var id: String
    /// Owner id in the old cloud store. Kept for import; empty in a local-only app.
    public var uid: String = ""
    public var createdAt: String
    /// "yyyy-MM-dd" local date.
    public var date: String
    /// "HH:mm" or "".
    public var startTime: String
    /// 1...5
    public var startStation: Int = 1
    public var session: Int = 1
    public var sessionId: String = ""
    public var type: String = "Training"
    public var scheme: Int = Schemes.defaultScheme
    public var field: Int?
    public var sky: String = ""
    public var wind: String = ""
    public var temperature: Double?
    public var humidity: Double?
    public var shooter: String = ""
    public var place: String = ""
    public var notes: String = ""
    public var weapon: String = ""
    public var ammo: String = ""
    public var choke1: String = ""
    public var choke2: String = ""
    public var appVersion: String = ""

    public var directions: [Direction?]
    public var results: [TargetResult?]
    /// Call-to-first-shot, seconds.
    public var firstShot: [Double?]
    /// Call-to-second-shot, seconds.
    public var secondShot: [Double?]
    /// Call level, dB.
    public var callLevel: [Double?]
    /// Microphone label used by the timer.
    public var timerMic: [String]
    /// NO TARGET presses.
    public var noTarget: [Int]

    public init(id: String, createdAt: String, date: String, startTime: String) {
        self.id = id
        self.createdAt = createdAt
        self.date = date
        self.startTime = startTime
        let n = Round.targetCount
        directions = Array(repeating: nil, count: n)
        results = Array(repeating: nil, count: n)
        firstShot = Array(repeating: nil, count: n)
        secondShot = Array(repeating: nil, count: n)
        callLevel = Array(repeating: nil, count: n)
        timerMic = Array(repeating: "", count: n)
        noTarget = Array(repeating: 0, count: n)
    }

    /// A fresh round for now, with a new id.
    public static func new(now: Date = Date()) -> Round {
        Round(id: RoundID.make(now: now), createdAt: DateText.iso(now), date: DateText.day(now), startTime: DateText.hourMinute(now))
    }

    /// Station (0...4) of target `i`. The shooter picks the first station; the round then runs 3, 4, 5, 1, 2, 3 ...
    public func stationIndex(at i: Int) -> Int { (startStation - 1 + i) % Round.stationCount }
    /// Station number (1...5) of target `i`.
    public func station(at i: Int) -> Int { stationIndex(at: i) + 1 }
    /// The machine that threw target `i`, when its direction is recorded.
    public func machine(at i: Int) -> TrapMachine? {
        guard let d = directions[i] else { return nil }
        return Schemes.machine(scheme: scheme, station: station(at: i), direction: d)
    }
    /// Number of NO TARGET presses on target `i`.
    public func noTargetCount(at i: Int) -> Int { max(0, noTarget[i]) }
}

/// Round ids in the web app's format: "r" + base-36 milliseconds + 3 random base-36 characters.
public enum RoundID {
    public static func make(now: Date = Date()) -> String {
        let ms = Int64(now.timeIntervalSince1970 * 1000)
        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        let tail = String((0..<3).map { _ in digits[Int.random(in: 0..<digits.count)] })
        return "r" + String(ms, radix: 36) + tail
    }
}

/// Date strings in the formats the round document uses.
public enum DateText {
    private static func formatter(_ f: String) -> DateFormatter {
        let d = DateFormatter()
        d.locale = Locale(identifier: "en_US_POSIX")
        d.dateFormat = f
        return d
    }
    /// Local date, "yyyy-MM-dd".
    public static func day(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }
    /// Local time, "HH:mm".
    public static func hourMinute(_ date: Date) -> String { formatter("HH:mm").string(from: date) }
    /// UTC timestamp with milliseconds, like JavaScript's toISOString().
    public static func iso(_ date: Date) -> String {
        let f = formatter("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}
