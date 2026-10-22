import Foundation

/// Session id: date, start time and the shooter's initials, e.g. "20261022-0930-MT", "-2", "-3" on collision.
public enum SessionID {
    public static func initials(_ name: String) -> String {
        let words = name.trimmingCharacters(in: .whitespaces).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        if words.isEmpty { return "USR" }
        if words.count == 1 { return String(words[0].prefix(3)).uppercased() }
        return words.prefix(3).map { String($0.prefix(1)) }.joined().uppercased()
    }

    public static func base(date: String, startTime: String, shooter: String, now: Date = Date()) -> String {
        let d = (date.isEmpty ? DateText.day(now) : date).replacingOccurrences(of: "-", with: "")
        let t = (startTime.isEmpty ? "0000" : startTime).replacingOccurrences(of: ":", with: "")
        return d + "-" + t + "-" + initials(shooter)
    }

    /// Unique id among `existing` (other rounds' (id, sessionId) pairs; the round's own id is skipped).
    public static func make(for round: Round, existing: [(id: String, sessionId: String)], now: Date = Date()) -> String {
        let b = base(date: round.date, startTime: round.startTime, shooter: round.shooter, now: now)
        var id = b, n = 2
        while existing.contains(where: { $0.id != round.id && $0.sessionId == id }) { id = b + "-" + String(n); n += 1 }
        return id
    }
}
