import Foundation

/// Round document v2: the JSON shape the 7.x web app stores and exports.
/// Decoding is tolerant, exactly like the web app's `norm`: wrong types fall back to defaults,
/// short arrays are padded, long arrays are cut, unknown schemes become scheme 2.
public enum RoundDocument {
    public static let version = 2

    /// Builds a round from a document dictionary (parsed JSON). `id` is the row id, not part of the document.
    public static func round(id: String, from d: [String: Any], now: Date = Date()) -> Round {
        var r = Round(id: id, createdAt: DateText.iso(now), date: DateText.day(now), startTime: "")
        func str(_ k: String) -> String? { d[k] as? String }
        func num(_ k: String) -> Double? { jsonNumber(d[k]) }
        func isNull(_ k: String) -> Bool { d[k] is NSNull }

        if let v = str("uid") { r.uid = v }
        if let v = str("createdAt") { r.createdAt = v }
        if let v = str("date") { r.date = v }
        if let v = str("startTime") { r.startTime = v }
        if let v = str("sessionId") { r.sessionId = v }
        if let v = str("type") { r.type = v }
        if let v = str("sky") { r.sky = v }
        if let v = str("wind") { r.wind = v }
        if let v = str("shooter") { r.shooter = v }
        if let v = str("place") { r.place = v }
        if let v = str("notes") { r.notes = v }
        if let v = str("weapon") { r.weapon = v }
        if let v = str("ammo") { r.ammo = v }
        if let v = str("choke1") { r.choke1 = v }
        if let v = str("choke2") { r.choke2 = v }
        if let v = str("ver") { r.appVersion = v }

        if let v = num("session"), let i = JSMath.safeInt(v) { r.session = i }   // session is an integer count
        if let v = num("scheme") { r.scheme = Int(exactly: v) ?? -1 }    // 3.5 is not a scheme
        if let v = num("field") { r.field = JSMath.safeInt(v) } else if isNull("field") { r.field = nil }
        if let v = num("temp") { r.temperature = v } else if isNull("temp") { r.temperature = nil }
        if let v = num("hum") { r.humidity = v } else if isNull("hum") { r.humidity = nil }
        if let v = num("startStn"), v >= 1, v <= 5, let s = Int(exactly: v) { r.startStation = s }
        if !Schemes.isValid(r.scheme) { r.scheme = Schemes.defaultScheme }

        let n = Round.targetCount
        if let s = str("dirs"), s.count == n { r.directions = s.map { Direction(rawValue: String($0)) } }
        if let s = str("res"), s.count == n { r.results = s.map { TargetResult(rawValue: String($0)) } }
        func doubles(_ k: String) -> [Double?]? {
            guard let a = d[k] as? [Any] else { return nil }
            var out: [Double?] = a.prefix(n).map { jsonNumber($0) }
            while out.count < n { out.append(nil) }
            return out
        }
        if let a = doubles("t1") { r.firstShot = a }
        if let a = doubles("t2") { r.secondShot = a }
        if let a = doubles("call") { r.callLevel = a }
        if let a = d["tmic"] as? [Any] {
            var out: [String] = a.prefix(n).map { ($0 as? String) ?? "" }
            while out.count < n { out.append("") }
            r.timerMic = out
        }
        if let a = d["nt"] as? [Any] {
            var out: [Int] = a.prefix(n).map { v in
                guard let x = jsonNumber(v), x > 0, let i = JSMath.safeInt(x.rounded(.toNearestOrAwayFromZero)) else { return 0 }
                return min(i, 9_999)
            }
            while out.count < n { out.append(0) }
            r.noTarget = out
        }
        return r
    }

    /// A JSON number as Double; JSON true/false and null are not numbers (JSONSerialization boxes booleans as NSNumber too).
    static func jsonNumber(_ v: Any?) -> Double? {
        guard let n = v as? NSNumber else { return nil }
        if CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
        return n.doubleValue
    }

    public static func round(id: String, fromJSON data: Data) throws -> Round {
        guard let d = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "TrapCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not a round document."])
        }
        return round(id: id, from: d)
    }

    /// The document dictionary of a round (the web app's `toDoc`). `updatedAt` is `now`.
    public static func document(of r: Round, now: Date = Date()) -> [String: Any] {
        func opt(_ v: Double?) -> Any { v.map { jsNumber($0) } ?? NSNull() }
        func optInt(_ v: Int?) -> Any { v.map { $0 as Any } ?? NSNull() }
        return [
            "v": version, "ver": r.appVersion, "uid": r.uid, "createdAt": r.createdAt, "updatedAt": DateText.iso(now),
            "date": r.date, "startTime": r.startTime, "startStn": r.startStation, "session": r.session, "sessionId": r.sessionId,
            "type": r.type, "scheme": r.scheme, "field": optInt(r.field), "sky": r.sky, "wind": r.wind,
            "temp": opt(r.temperature), "hum": opt(r.humidity),
            "shooter": r.shooter, "place": r.place, "notes": r.notes, "weapon": r.weapon, "ammo": r.ammo, "choke1": r.choke1, "choke2": r.choke2,
            "dirs": String(r.directions.map { $0?.rawValue.first ?? "-" }),
            "res": String(r.results.map { $0?.rawValue.first ?? "-" }),
            "t1": r.firstShot.map(opt), "t2": r.secondShot.map(opt), "call": r.callLevel.map(opt),
            "tmic": r.timerMic, "nt": r.noTarget
        ]
    }

    public static func json(of r: Round, now: Date = Date(), pretty: Bool = false) throws -> Data {
        try JSONSerialization.data(withJSONObject: document(of: r, now: now), options: pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys])
    }

    /// A number as JSON wants it: integral values without a fraction.
    static func jsNumber(_ v: Double) -> Any {
        if v.isFinite, v == v.rounded(), abs(v) < 9_007_199_254_740_992 { return Int64(v) }
        return v
    }
}
