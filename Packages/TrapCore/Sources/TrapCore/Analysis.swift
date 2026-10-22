import Foundation

/// Totals over a list of rounds.
public struct RoundStats: Equatable, Sendable {
    public var rounds = 0
    /// Targets with a result.
    public var targets = 0
    public var hits = 0
    /// Hits with the first shot.
    public var firstShotHits = 0
}

/// One line of an analysis table.
public struct AnalysisRow: Equatable, Sendable {
    public let key: String
    public let targets: Int
    public let hits: Int
    public let firstShotHits: Int
    public var hitRate: Double { targets > 0 ? Double(hits) / Double(targets) : 0 }
}

/// One dimension of the analysis (direction, station, angle band ...), with its rows in display order.
public struct AnalysisTable: Equatable, Sendable {
    public let title: String
    public let rows: [AnalysisRow]
}

/// Your analysis: hit rates by direction, station, angle, height, position, scheme, sky, wind, temperature and humidity.
public enum Analysis {
    public static let angleBands = ["0 to 10°", "15 to 25°", "30 to 35°", "40 to 45°"]
    public static let heightBands = ["Under 2.0 m", "2.0 to 2.5 m", "Over 2.5 m"]
    public static let temperatureBands = ["Under 15 °C", "15 to 24 °C", "25 °C and over"]
    public static let humidityBands = ["Under 40 %", "40 to 59 %", "60 % and over"]
    public static let blocks = ["Shots 1 to 5", "Shots 6 to 10", "Shots 11 to 15", "Shots 16 to 20", "Shots 21 to 25"]

    struct Dimension {
        let title: String
        let order: [String]
        let key: (Round, Int) -> String?
    }

    static let dimensions: [Dimension] = [
        Dimension(title: "Direction", order: ["Left", "Straight", "Right"]) { r, i in r.directions[i]?.name },
        Dimension(title: "Station", order: ["1", "2", "3", "4", "5"]) { r, i in String(r.station(at: i)) },
        Dimension(title: "Angle", order: angleBands) { r, i in
            guard let t = r.machine(at: i) else { return nil }
            let a = abs(t.angle)
            return a <= 10 ? angleBands[0] : a <= 25 ? angleBands[1] : a <= 35 ? angleBands[2] : angleBands[3]
        },
        Dimension(title: "Height at 10 m", order: heightBands) { r, i in
            guard let t = r.machine(at: i) else { return nil }
            return t.height < 2 ? heightBands[0] : t.height <= 2.5 ? heightBands[1] : heightBands[2]
        },
        Dimension(title: "Position in round", order: blocks) { _, i in blocks[i / 5] },
        Dimension(title: "Scheme", order: (1...10).map(String.init)) { r, _ in String(r.scheme) },
        Dimension(title: "Sky", order: Sky.names) { r, _ in Sky(rawValue: r.sky)?.name },
        Dimension(title: "Wind", order: Wind.names) { r, _ in Wind(rawValue: r.wind)?.name },
        Dimension(title: "Temperature", order: temperatureBands) { r, _ in
            guard let t = r.temperature else { return nil }
            return t < 15 ? temperatureBands[0] : t < 25 ? temperatureBands[1] : temperatureBands[2]
        },
        Dimension(title: "Humidity", order: humidityBands) { r, _ in
            guard let h = r.humidity else { return nil }
            return h < 40 ? humidityBands[0] : h < 60 ? humidityBands[1] : humidityBands[2]
        }
    ]

    public static func stats(_ list: [Round]) -> RoundStats {
        var o = RoundStats(rounds: list.count)
        for r in list { o.targets += r.recorded; o.hits += r.score; o.firstShotHits += r.counts.hitFirst }
        return o
    }

    /// Tables for every dimension that has data, rows in the dimension's display order.
    public static func tables(_ list: [Round]) -> [AnalysisTable] {
        dimensions.compactMap { dim in
            var g: [String: (n: Int, hit: Int, g: Int)] = [:]
            for r in list {
                for i in 0..<Round.targetCount {
                    guard let res = r.results[i], let k = dim.key(r, i) else { continue }
                    var o = g[k] ?? (0, 0, 0)
                    o.n += 1
                    if res.isHit { o.hit += 1 }
                    if res == .hitFirst { o.g += 1 }
                    g[k] = o
                }
            }
            let rows = dim.order.compactMap { k -> AnalysisRow? in
                guard let o = g[k] else { return nil }
                return AnalysisRow(key: k, targets: o.n, hits: o.hit, firstShotHits: o.g)
            }
            return rows.isEmpty ? nil : AnalysisTable(title: dim.title, rows: rows)
        }
    }

    /// "72.0%" or "–".
    public static func percent(_ a: Int, _ b: Int) -> String { b > 0 ? String(format: "%.1f%%", 100 * Double(a) / Double(b)) : "–" }
}
