import Foundation

/// Least-squares fit of first-shot time against trap angle and height: t = b0 + b1·angle + b2·height.
public struct GeometryFit: Equatable, Sendable {
    public let b0: Double, b1: Double, b2: Double
    /// Coefficient of determination, 0...1.
    public let r2: Double
    public func predicted(angle: Double, height: Double) -> Double { b0 + b1 * angle + b2 * height }
}

/// One trap machine's record within a scheme.
public struct TrapStat: Equatable, Sendable {
    public let number: Int
    public let station: Int
    public let label: String
    /// Unsigned angle.
    public let angle: Int
    public let height: Double
    public var shots = 0, hitFirst = 0, hitSecond = 0, lost = 0
    /// First-shot times that survived the outlier filter, seconds.
    public var times: [Double] = []
    public var averageTime: Double?
    /// Average minus the fit's prediction for this trap, ms. Negative is faster than your own pattern.
    public var versusFit: Double?
    public var hits: Int { hitFirst + hitSecond }
}

public struct StationStat: Equatable, Sendable {
    public let station: Int
    public var shots = 0, hitFirst = 0, hitSecond = 0, lost = 0
    public var hits: Int { hitFirst + hitSecond }
}

public struct HitBucket: Equatable, Sendable {
    public var targets = 0, hits = 0
}

/// How first-shot timing relates to misses: faster than usual, about usual, slower than usual.
public struct DeviationBand: Equatable, Sendable {
    public let key: String
    public var targets = 0, misses = 0
}

/// Trap analysis of one scheme over a list of rounds (the web app's `trapStats`).
public struct TrapAnalysis: Equatable, Sendable {
    public let scheme: Int
    /// Rounds of this scheme with data.
    public let rounds: Int
    /// Rounds with data of other schemes.
    public let skipped: Int
    public let traps: [TrapStat]
    public let stations: [StationStat]
    public let totals: StationStat
    public let fit: GeometryFit?
    /// First shots used for timing figures.
    public let timed: Int
    /// First shots dropped as outliers (more than 0.25 s from the median).
    public let outliers: Int
    public let averageTime: Double?
    /// Targets 1 to 5 of each round.
    public let early: HitBucket
    /// Targets 6 to 25.
    public let late: HitBucket
    public let deviations: [DeviationBand]
}

/// Overview tiles of the Analysis tab.
public struct Overview: Equatable, Sendable {
    public let rounds: Int
    public let fullRounds: Int
    public let averageScore: Double?
    public let bestScore: Int?
    public let targets: Int, hits: Int, firstBarrel: Int, secondBarrel: Int
    public var averageScoreText: String { averageScore.map { JSText.fixed($0, 1) } ?? "–" }
    public var bestScoreText: String { bestScore.map(String.init) ?? "–" }
    public var hitRateText: String { Analysis.percent(hits, targets) }
    public var firstBarrelText: String { Analysis.percent(firstBarrel, targets) }
    public var secondBarrelText: String { Analysis.percent(secondBarrel, targets) }
}

/// One bar of the score trend.
public struct TrendPoint: Equatable, Sendable {
    public let roundID: String
    public let date: String
    public let score: Int
}

public extension Analysis {
    // MARK: scheme selection

    /// Rounds with data per scheme.
    static func schemeCounts(_ list: [Round]) -> [Int: Int] {
        var c: [Int: Int] = [:]
        for r in list where r.recorded > 0 { c[r.scheme, default: 0] += 1 }
        return c
    }
    /// The scheme with most rounds; the lowest scheme number on a tie.
    static func dominantScheme(_ list: [Round]) -> Int? {
        let c = schemeCounts(list)
        var best: Int?
        for k in c.keys.sorted() where best == nil || c[k]! > c[best!]! { best = k }
        return best
    }

    // MARK: overview and trend

    static func overview(_ list: [Round]) -> Overview {
        let full = list.filter { $0.recorded == Round.targetCount }
        let all = stats(list)
        var best = 0, sum = 0, g = 0, y = 0
        for r in full { let sc = r.score; sum += sc; best = max(best, sc) }
        for r in list { let c = r.counts; g += c.hitFirst; y += c.hitSecond }
        return Overview(rounds: list.count, fullRounds: full.count,
                        averageScore: full.isEmpty ? nil : Double(sum) / Double(full.count),
                        bestScore: full.isEmpty ? nil : best,
                        targets: all.targets, hits: all.hits, firstBarrel: g, secondBarrel: y)
    }

    /// Scores of the last `limit` full rounds, oldest first.
    static func trend(_ list: [Round], limit: Int = 14) -> [TrendPoint] {
        let full = list.filter { $0.recorded == Round.targetCount }.sorted { $0.createdAt < $1.createdAt }
        return full.suffix(limit).map { TrendPoint(roundID: $0.id, date: $0.date, score: $0.score) }
    }

    // MARK: trap analysis

    /// Solves a 3×3 linear system by Gaussian elimination with partial pivoting; nil when singular.
    static func solve3(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        var M = (0..<3).map { A[$0] + [b[$0]] }
        let n = 3
        for i in 0..<n {
            var p = i
            for k in (i + 1)..<n where abs(M[k][i]) > abs(M[p][i]) { p = k }
            if abs(M[p][i]) < 1e-9 { return nil }
            M.swapAt(i, p)
            for k in (i + 1)..<n {
                let f = M[k][i] / M[i][i]
                for j in i...n { M[k][j] -= f * M[i][j] }
            }
        }
        var x = [0.0, 0.0, 0.0]
        for i in stride(from: n - 1, through: 0, by: -1) {
            var s = M[i][n]
            for j in (i + 1)..<n { s -= M[i][j] * x[j] }
            x[i] = s / M[i][i]
        }
        return x
    }

    struct TimedPoint { let angle: Double, height: Double, time: Double, trap: Int, result: TargetResult }

    /// Needs at least 30 points.
    static func fitGeometry(_ pts: [TimedPoint]) -> GeometryFit? {
        let n = pts.count
        guard n >= 30 else { return nil }
        var S = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]], B = [0.0, 0.0, 0.0], sy = 0.0, syy = 0.0
        for p in pts {
            let x = [1.0, p.angle, p.height]
            for i in 0..<3 { for j in 0..<3 { S[i][j] += x[i] * x[j] }; B[i] += x[i] * p.time }
            sy += p.time; syy += p.time * p.time
        }
        guard let be = solve3(S, B) else { return nil }
        let mean = sy / Double(n), sst = syy - Double(n) * mean * mean
        var sse = 0.0
        for p in pts { let e = p.time - (be[0] + be[1] * p.angle + be[2] * p.height); sse += e * e }
        return GeometryFit(b0: be[0], b1: be[1], b2: be[2], r2: sst > 0 ? 1 - sse / sst : 0)
    }

    static func trapAnalysis(_ list: [Round], scheme: Int) -> TrapAnalysis {
        var byTrap: [Int: TrapStat] = [:], order: [Int] = []
        var pts: [TimedPoint] = []
        var skipped = 0, used = 0
        var stations = (1...5).map { StationStat(station: $0) }
        var totals = StationStat(station: 0)
        var early = HitBucket(), late = HitBucket()
        for r in list where r.recorded > 0 {
            if r.scheme != scheme { skipped += 1; continue }
            used += 1
            for i in 0..<Round.targetCount {
                guard let d = r.directions[i], let res = r.results[i] else { continue }
                let stn = r.station(at: i)
                guard let tr = Schemes.machine(scheme: scheme, station: stn, direction: d) else { continue }
                if byTrap[tr.number] == nil {
                    byTrap[tr.number] = TrapStat(number: tr.number, station: stn, label: tr.label, angle: abs(tr.angle), height: tr.height)
                    order.append(tr.number)
                }
                byTrap[tr.number]!.shots += 1; stations[stn - 1].shots += 1; totals.shots += 1
                switch res {
                case .hitFirst: byTrap[tr.number]!.hitFirst += 1; stations[stn - 1].hitFirst += 1; totals.hitFirst += 1
                case .hitSecond: byTrap[tr.number]!.hitSecond += 1; stations[stn - 1].hitSecond += 1; totals.hitSecond += 1
                case .lost: byTrap[tr.number]!.lost += 1; stations[stn - 1].lost += 1; totals.lost += 1
                }
                if i < 5 { early.targets += 1; if res.isHit { early.hits += 1 } } else { late.targets += 1; if res.isHit { late.hits += 1 } }
                if let t = r.firstShot[i] {
                    pts.append(TimedPoint(angle: Double(abs(tr.angle)), height: tr.height, time: t, trap: tr.number, result: res))
                }
            }
        }
        // a first shot more than 0.25 s from the median is a mis-trigger or a mis-key: leave it out of the timing figures
        var outliers = 0
        if !pts.isEmpty {
            let sorted = pts.map(\.time).sorted()
            let median = sorted[sorted.count / 2]
            let kept = pts.filter { abs($0.time - median) <= 0.25 }
            outliers = pts.count - kept.count
            pts = kept
        }
        for p in pts { byTrap[p.trap]!.times.append(p.time) }
        let fit = fitGeometry(pts)
        let tsum = pts.reduce(0.0) { $0 + $1.time }
        var traps = order.sorted().map { byTrap[$0]! }
        for i in traps.indices {
            let t = traps[i]
            traps[i].averageTime = t.times.isEmpty ? nil : t.times.reduce(0, +) / Double(t.times.count)
            if let f = fit, let avg = traps[i].averageTime {
                traps[i].versusFit = (avg - f.predicted(angle: Double(t.angle), height: t.height)) * 1000
            }
        }
        let trapIndex = Dictionary(uniqueKeysWithValues: traps.enumerated().map { ($1.number, $0) })
        var dev = [DeviationBand(key: "More than 20 ms faster"), DeviationBand(key: "Within 20 ms"), DeviationBand(key: "More than 20 ms slower")]
        for p in pts {
            let o = traps[trapIndex[p.trap]!]
            guard o.times.count >= 3, let avg = o.averageTime else { continue }
            let dv = (p.time - avg) * 1000
            let g = dv < -20 ? 0 : dv > 20 ? 2 : 1
            dev[g].targets += 1
            if p.result == .lost { dev[g].misses += 1 }
        }
        return TrapAnalysis(scheme: scheme, rounds: used, skipped: skipped, traps: traps, stations: stations, totals: totals,
                            fit: fit, timed: pts.count, outliers: outliers, averageTime: pts.isEmpty ? nil : tsum / Double(pts.count),
                            early: early, late: late, deviations: dev)
    }

    // MARK: findings

    static func angleLabel(_ l: String) -> String { l == "0" ? "straight" : l }
    static func heightLabel(_ h: Double) -> String { JSText.number(jsRound(h * 100) / 100) + " m" }
    /// JavaScript Math.round: halves go up.
    static func jsRound(_ x: Double) -> Double { JSMath.round(x) }

    /// Plain-language findings of a trap analysis, in the web app's wording.
    static func findings(_ a: TrapAnalysis) -> [String] {
        var f: [String] = []
        let tot = a.totals, hits = tot.hits
        guard tot.shots > 0 else { return f }
        let rate = Double(hits) / Double(tot.shots)
        f.append("You hit \(hits) of \(tot.shots) (\(percent(hits, tot.shots))). Over 125 targets that projects to about \(Int(jsRound(rate * 125))).")
        let tr = a.traps.filter { $0.shots >= 5 }
        if !tr.isEmpty {
            func hitRate(_ o: TrapStat) -> Double { Double(o.hits) / Double(o.shots) }
            let rank = tr.sorted { x, y in
                if hitRate(x) != hitRate(y) { return hitRate(x) < hitRate(y) }
                if x.lost != y.lost { return x.lost > y.lost }
                return x.number < y.number
            }
            let w = rank[0]
            if w.lost > 0 {
                f.append("Weakest trap: trap \(w.number) (\(angleLabel(w.label)), \(heightLabel(w.height))). It hit \(percent(w.hits, w.shots)) (\(w.hits) of \(w.shots)), \(w.lost)\(w.lost == 1 ? " miss" : " misses").")
            }
            let fb = tr.sorted { x, y in
                let fx = Double(x.hitFirst) / Double(x.shots), fy = Double(y.hitFirst) / Double(y.shots)
                if fx != fy { return fx > fy }
                if x.shots != y.shots { return x.shots > y.shots }
                return x.number < y.number
            }[0]
            f.append("Best on the first barrel: trap \(fb.number) (\(angleLabel(fb.label)), \(heightLabel(fb.height))). \(fb.hitFirst) of \(fb.shots) broke on the first shot.")
            let low = tr.filter { $0.number != w.number && $0.lost >= 2 && hitRate($0) < rate - 0.05 }.prefix(2)
            for o in low {
                f.append("Also below your average: trap \(o.number) (\(angleLabel(o.label)), \(heightLabel(o.height))), \(percent(o.hits, o.shots)) on \(o.shots) shots.")
            }
        }
        let withShots = a.stations.filter { $0.shots > 0 }
        if let sm = withShots.sorted(by: { $0.lost != $1.lost ? $0.lost > $1.lost : $0.station < $1.station }).first, sm.lost > 0 {
            f.append("Most misses at station \(sm.station): \(sm.lost) of \(sm.shots) (\(percent(sm.lost, sm.shots))).")
        }
        let secondLeaners = withShots.filter { $0.hits >= 5 }.sorted { x, y in
            let rx = Double(x.hitSecond) / Double(x.hits), ry = Double(y.hitSecond) / Double(y.hits)
            return rx != ry ? rx > ry : x.station < y.station
        }
        if let sy = secondLeaners.first, sy.hitSecond > 0 {
            f.append("Station \(sy.station) leaned on the second barrel: \(sy.hitSecond) of \(sy.hits) hits.")
        }
        if a.rounds >= 3, a.early.targets >= 15, a.late.targets >= 15 {
            let e = Double(a.early.hits) / Double(a.early.targets), l = Double(a.late.hits) / Double(a.late.targets)
            let tail = e + 0.08 < l ? ". A slow start costs you targets." : e > l + 0.08 ? ". You start stronger than you finish." : "."
            f.append("First 5 targets of a round: \(percent(a.early.hits, a.early.targets)). The other 20: \(percent(a.late.hits, a.late.targets))\(tail)")
        }
        if let fit = a.fit {
            f.append("Shot time follows the trap: about \(JSText.fixed(fit.b1 * 1000, 1)) ms per degree of angle and \(JSText.fixed(fit.b2 * 1000, 0)) ms per metre of height (fit \(Int(jsRound(fit.r2 * 100)))%).")
        }
        return f
    }

    /// "+12 ms", "−8 ms", "0 ms" or "–".
    static func signedMs(_ v: Double?) -> String {
        guard let v else { return "–" }
        let sign = v > 0 ? "+" : v < 0 ? "−" : ""
        return sign + String(Int(abs(jsRound(v)))) + " ms"
    }
}
