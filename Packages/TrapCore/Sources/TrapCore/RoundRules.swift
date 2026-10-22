import Foundation

/// Per-direction counts for a station.
public struct DirectionCounts: Equatable, Sendable {
    public var right = 0, straight = 0, left = 0
    public subscript(d: Direction) -> Int {
        get { switch d { case .right: return right; case .straight: return straight; case .left: return left } }
        set { switch d { case .right: right = newValue; case .straight: straight = newValue; case .left: left = newValue } }
    }
}

/// Hit/lost counts of a round.
public struct ResultCounts: Equatable, Sendable {
    public var hitFirst = 0, hitSecond = 0, lost = 0
    public var hits: Int { hitFirst + hitSecond }
}

/// Chance of each direction at a target.
public struct DirectionOdds: Equatable, Sendable {
    public var right = 0.0, straight = 0.0, left = 0.0
    public subscript(d: Direction) -> Double {
        switch d { case .right: return right; case .straight: return straight; case .left: return left }
    }
}

/// A predicted direction for an unrecorded target.
public struct Prediction: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public let index: Int
        public let station: Int
        public let odds: DirectionOdds
        /// Set when one direction is certain.
        public let exact: Direction?
    }
    public let recordedDirections: Int
    public let ready: Bool
    public let items: [Item]
}

/// The station rule of Olympic Trap and everything derived from it.
/// Each station gets exactly 2 right, 1 straight and 2 left over the 25 targets.
public extension Round {
    /// Predictions start after this many directions are recorded.
    static let predictionFrom = 15

    var score: Int { results.reduce(0) { $0 + (($1?.isHit ?? false) ? 1 : 0) } }
    var counts: ResultCounts {
        var c = ResultCounts()
        for r in results {
            switch r { case .hitFirst?: c.hitFirst += 1; case .hitSecond?: c.hitSecond += 1; case .lost?: c.lost += 1; case nil: break }
        }
        return c
    }
    /// Targets with a result.
    var recorded: Int { results.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
    /// Targets with a direction.
    var directionsRecorded: Int { directions.reduce(0) { $0 + ($1 == nil ? 0 : 1) } }
    /// Anything entered at all (direction, result or a time).
    var hasData: Bool {
        for i in 0..<Round.targetCount where directions[i] != nil || results[i] != nil || firstShot[i] != nil || secondShot[i] != nil { return true }
        return false
    }
    func isIncomplete(at i: Int) -> Bool { directions[i] == nil || results[i] == nil }
    func nextIncomplete(after from: Int) -> Int {
        for k in 1...Round.targetCount { let j = (from + k) % Round.targetCount; if isIncomplete(at: j) { return j } }
        return from
    }
    var firstIncomplete: Int { (0..<Round.targetCount).first { isIncomplete(at: $0) } ?? 0 }

    /// Directions already recorded at station index `s` (0...4), ignoring target `skipping`.
    func stationCounts(stationIndex s: Int, skipping: Int? = nil) -> DirectionCounts {
        var c = DirectionCounts()
        for i in 0..<Round.targetCount where i != skipping && stationIndex(at: i) == s {
            if let d = directions[i] { c[d] += 1 }
        }
        return c
    }
    /// True when a station already has more of a direction than the rule allows.
    func stationOver(stationIndex s: Int) -> Bool {
        let c = stationCounts(stationIndex: s)
        return c.right > Direction.right.quota || c.straight > Direction.straight.quota || c.left > Direction.left.quota
    }
    /// True when recording `d` at target `i` would exceed the station's quota for that direction.
    func isFull(at i: Int, direction d: Direction) -> Bool {
        stationCounts(stationIndex: stationIndex(at: i), skipping: i)[d] >= d.quota
    }
    /// Chance of each direction at target `i`: what its station still owes, shared over the open slots.
    func directionOdds(at i: Int) -> DirectionOdds {
        let used = stationCounts(stationIndex: stationIndex(at: i), skipping: i)
        var rem = DirectionCounts(), sum = 0
        for d in Direction.allCases { rem[d] = max(0, d.quota - used[d]); sum += rem[d] }
        var p = DirectionOdds()
        p.right = sum > 0 ? Double(rem.right) / Double(sum) : 0
        p.straight = sum > 0 ? Double(rem.straight) / Double(sum) : 0
        p.left = sum > 0 ? Double(rem.left) / Double(sum) : 0
        return p
    }
    /// Predicted directions of the targets not yet recorded, once enough directions are known.
    func prediction() -> Prediction {
        let have = directionsRecorded
        guard have >= Round.predictionFrom else { return Prediction(recordedDirections: have, ready: false, items: []) }
        var items: [Prediction.Item] = []
        for s in 0..<Round.stationCount {
            let used = stationCounts(stationIndex: s)
            let open = (0..<Round.targetCount).filter { stationIndex(at: $0) == s && directions[$0] == nil }
            if open.isEmpty || stationOver(stationIndex: s) { continue }
            for i in open {
                var p = DirectionOdds(), exact: Direction?
                for d in Direction.displayOrder {
                    let v = Double(d.quota - used[d]) / Double(open.count)
                    switch d { case .right: p.right = v; case .straight: p.straight = v; case .left: p.left = v }
                    if v >= 0.999 { exact = d }
                }
                items.append(Prediction.Item(index: i, station: s + 1, odds: p, exact: exact))
            }
        }
        items.sort { $0.index < $1.index }
        return Prediction(recordedDirections: have, ready: true, items: items)
    }
}

/// Colour grade of a probability: 0 none, 1 under 30 %, 2 under 50 %, 3 under 75 %, 4 otherwise.
public enum Grade {
    public static func of(_ p: Double) -> Int { p <= 0 ? 0 : p < 0.3 ? 1 : p < 0.5 ? 2 : p < 0.75 ? 3 : 4 }
}
