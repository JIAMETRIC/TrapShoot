import Foundation

/// CSV export, one row per recorded target. Same columns and formatting as the web app 7.0.7.
public enum CSVExport {
    public static let header = ["round_id", "shooter_id", "date", "start_time", "start_station", "session", "session_id", "round_type", "scheme", "field", "sky", "wind", "temp_c", "humidity_pct", "shooter",
                                "place", "weapon", "ammo", "choke_1st", "choke_2nd", "seq", "station", "direction", "trap", "side", "angle_deg", "angle_signed_deg", "height_m", "status", "hit", "first_shot_s", "second_shot_s", "notes", "call_db", "timer_mic", "break_m", "break_shot", "release_delay_ms", "shot_v1_ms", "shot_size", "no_target"]

    public static func csv(rounds: [Round], breakModel: BreakDistanceModel) -> String {
        var out = [header.joined(separator: ",")]
        let b = breakModel.settings
        for r in rounds {
            for i in 0..<Round.targetCount {
                let d = r.directions[i], st = r.results[i]
                if d == nil && st == nil && r.firstShot[i] == nil && r.secondShot[i] == nil && r.noTargetCount(at: i) == 0 { continue }
                let stn = r.station(at: i)
                let t = d.flatMap { Schemes.machine(scheme: r.scheme, station: stn, direction: $0) }
                let brk = r.breakDistance(at: i, model: breakModel)
                let row: [Any?] = [r.id, r.uid, r.date, r.startTime, r.startStation, r.session, r.sessionId, r.type, r.scheme, r.field, r.sky, r.wind, r.temperature, r.humidity, r.shooter,
                                   r.place, r.weapon, r.ammo, r.choke1, r.choke2, i + 1, stn, d?.rawValue, t?.number, t?.side, t?.angle, t?.signedAngle, t?.height,
                                   st?.rawValue, st.map { $0.isHit ? 1 : 0 }, r.firstShot[i], r.secondShot[i], r.notes, r.callLevel[i], r.timerMic[i],
                                   brk, brk.map { _ in r.breakShot(at: i) }, b.releaseDelayMs, b.shotSpeed, b.shotSize.rawValue, r.noTargetCount(at: i)]
                out.append(row.map(cell).joined(separator: ","))
            }
        }
        return out.joined(separator: "\n")
    }

    /// One CSV cell: nil is empty, numbers print like JavaScript, quotes when needed.
    /// Text that starts with = + - @ or a tab is prefixed with an apostrophe so a spreadsheet never treats a
    /// shooter's note as a formula (CSV injection). Numbers are not text and are never touched.
    public static func cell(_ v: Any?) -> String {
        var s: String
        switch v {
        case nil: s = ""
        case let x as String: s = x
        case let x as Int: s = String(x)
        case let x as Double: s = JSText.number(x)
        default: s = "\(v!)"
        }
        if v is String, let first = s.first, "=+-@\t\r".contains(first) { s = "'" + s }
        if s.contains("\"") || s.contains(",") || s.contains("\n") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }
}

/// Text the way JavaScript's String(number) prints it, for exports that must match the web app byte for byte.
public enum JSText {
    public static func number(_ v: Double) -> String {
        if !v.isFinite { return v.isNaN ? "NaN" : (v < 0 ? "-Infinity" : "Infinity") }
        if v == v.rounded(), abs(v) < 9_007_199_254_740_992 { return String(Int64(v)) }   // beyond 2^53 fall through to the shortest form
        var s = "\(v)"                         // Swift prints the shortest round-trip form, like JavaScript
        if let e = s.range(of: "e") {          // 1e-07 -> 1e-7
            let mant = s[..<e.lowerBound], expo = s[e.upperBound...]
            let sign = expo.hasPrefix("-") ? "-" : "+"
            let digits = expo.drop { $0 == "-" || $0 == "+" }.drop { $0 == "0" }
            s = mant + "e" + sign + (digits.isEmpty ? "0" : String(digits))
        }
        return s
    }
}
