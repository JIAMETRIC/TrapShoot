import Foundation

/// What is wrong with a round. Imports, restores and the entry screens use the same rules.
public enum ValidationIssue: Equatable, UserFacingError {
    case badDate(String)
    case badStartTime(String)
    case badStartStation(Int)
    case badScheme(Int)
    case badSession(Int)
    case textTooLong(field: String, limit: Int)
    case temperatureOutOfRange(Double)
    case humidityOutOfRange(Double)
    case shotTimeOutOfRange(target: Int, seconds: Double)
    case secondBeforeFirst(target: Int)
    case stationOverQuota(station: Int)

    public var message: String {
        switch self {
        case .badDate(let d): return "The date \"\(d)\" is not in the form yyyy-mm-dd."
        case .badStartTime(let t): return "The start time \"\(t)\" is not in the form hh:mm."
        case .badStartStation(let s): return "Start station \(s) is not between 1 and 5."
        case .badScheme(let s): return "Scheme \(s) does not exist; schemes run 1 to 10."
        case .badSession(let s): return "Session \(s) must be 1 or more."
        case .textTooLong(let f, let l): return "\(f) is longer than \(l) characters."
        case .temperatureOutOfRange(let t): return "Temperature \(Int(t)) °C is outside -50 to 60."
        case .humidityOutOfRange(let h): return "Humidity \(Int(h)) % is outside 0 to 100."
        case .shotTimeOutOfRange(let i, let s): return "Target \(i + 1): a shot time of \(s) s is outside 0 to 5 s."
        case .secondBeforeFirst(let i): return "Target \(i + 1): the 2nd shot is before the 1st."
        case .stationOverQuota(let s): return "Station \(s) has more of one direction than the rule allows."
        }
    }
}

public enum Validation {
    public static let textLimit = 200
    public static let notesLimit = 2000
    public static let maxShotSeconds = 5.0

    static let dateRegex = try! NSRegularExpression(pattern: "^\\d{4}-\\d{2}-\\d{2}$")
    static let timeRegex = try! NSRegularExpression(pattern: "^([01]\\d|2[0-3]):[0-5]\\d$")

    static func matches(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    /// Every problem, none fatal. An empty list means the round is clean.
    public static func issues(in r: Round) -> [ValidationIssue] {
        var out: [ValidationIssue] = []
        if !matches(dateRegex, r.date) { out.append(.badDate(r.date)) }
        if !r.startTime.isEmpty, !matches(timeRegex, r.startTime) { out.append(.badStartTime(r.startTime)) }
        if !(1...5).contains(r.startStation) { out.append(.badStartStation(r.startStation)) }
        if !Schemes.isValid(r.scheme) { out.append(.badScheme(r.scheme)) }
        if r.session < 1 { out.append(.badSession(r.session)) }
        for (name, value) in [("Shooter", r.shooter), ("Place", r.place), ("Weapon", r.weapon), ("Ammunition", r.ammo), ("1st choke", r.choke1), ("2nd choke", r.choke2), ("Type", r.type)] where value.count > textLimit {
            out.append(.textTooLong(field: name, limit: textLimit))
        }
        if r.notes.count > notesLimit { out.append(.textTooLong(field: "Notes", limit: notesLimit)) }
        if let t = r.temperature, !(-50...60).contains(t) { out.append(.temperatureOutOfRange(t)) }
        if let h = r.humidity, !(0...100).contains(h) { out.append(.humidityOutOfRange(h)) }
        for i in 0..<Round.targetCount {
            for t in [r.firstShot[i], r.secondShot[i]].compactMap({ $0 }) where !(0...maxShotSeconds).contains(t) || !t.isFinite {
                out.append(.shotTimeOutOfRange(target: i, seconds: t))
            }
            if let a = r.firstShot[i], let b = r.secondShot[i], b < a { out.append(.secondBeforeFirst(target: i)) }
        }
        for s in 0..<Round.stationCount where r.stationOver(stationIndex: s) { out.append(.stationOverQuota(station: s + 1)) }
        return out
    }

    /// Fixes what can be fixed without losing meaning: trims and caps text, clamps conditions, drops impossible times.
    /// Structural problems (date, scheme, quota) are left for the shooter and still reported by `issues(in:)`.
    public static func sanitized(_ input: Round) -> Round {
        var r = input
        func clean(_ s: String, _ limit: Int) -> String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\u{0}", with: "")
            return t.count > limit ? String(t.prefix(limit)) : t
        }
        r.shooter = clean(r.shooter, textLimit); r.place = clean(r.place, textLimit); r.weapon = clean(r.weapon, textLimit)
        r.ammo = clean(r.ammo, textLimit); r.choke1 = clean(r.choke1, textLimit); r.choke2 = clean(r.choke2, textLimit)
        r.type = clean(r.type, textLimit); r.notes = clean(r.notes, notesLimit)
        if let t = r.temperature { r.temperature = t.isFinite ? min(60, max(-50, t)) : nil }
        if let h = r.humidity { r.humidity = h.isFinite ? min(100, max(0, h)) : nil }
        if r.session < 1 { r.session = 1 }
        if let f = r.field, f < 1 { r.field = nil }
        for i in 0..<Round.targetCount {
            if let t = r.firstShot[i], !t.isFinite || !(0...maxShotSeconds).contains(t) { r.firstShot[i] = nil }
            if let t = r.secondShot[i], !t.isFinite || !(0...maxShotSeconds).contains(t) { r.secondShot[i] = nil }
            if let a = r.firstShot[i], let b = r.secondShot[i], b < a { r.secondShot[i] = nil }
            if let c = r.callLevel[i], !c.isFinite { r.callLevel[i] = nil }
            r.timerMic[i] = clean(r.timerMic[i], 80)
            r.noTarget[i] = max(0, min(99, r.noTarget[i]))
        }
        return r
    }
}
