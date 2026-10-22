import Foundation

/// Shot size, by its pellet diameter.
public enum ShotSize: String, CaseIterable, Codable, Sendable {
    case s7 = "7", s7_5 = "7.5", s8 = "8", s9 = "9"
    public var pelletMm: Double {
        switch self { case .s7: return 2.5; case .s7_5: return 2.4; case .s8: return 2.25; case .s9: return 2.0 }
    }
}

/// Break-distance settings (Timer tab > Break distance).
public struct BreakSettings: Equatable, Codable, Sendable {
    public var enabled = true
    /// Call to clay release, ms.
    public var releaseDelayMs: Double = 50
    /// Clay speed, m/s.
    public var claySpeed: Double = 28
    /// Shot speed V1, m/s (RC4 Champion Excellence 24 g: 415).
    public var shotSpeed: Double = 415
    public var shotSize: ShotSize = .s7_5
    public init() {}
}

/// Break distance of a hit target: the clay path of the scheme (angle and height at 10 m, station, machine position)
/// plus the shot flight time with air drag. Same model and constants as the web app (7.0.5).
public final class BreakDistanceModel {
    public let settings: BreakSettings
    private var shotTable: [Double] = []

    private static let g = 9.81, launchHeight = 0.45, eyeHeight = 1.6, stationToTrench = 15.0, tenMetres = 10.0
    private static let stationSpacing = 3.15, machineSpacing = 1.05
    private static let dragTable: [(Double, Double)] = [(0, 0.47), (0.6, 0.47), (0.8, 0.52), (0.9, 0.6), (1, 0.78), (1.1, 0.88), (1.2, 0.93), (1.5, 0.97), (3, 0.97)]

    public init(settings: BreakSettings = BreakSettings()) {
        self.settings = settings
        buildShotTable()
    }

    private static func sphereCd(_ mach: Double) -> Double {
        let t = dragTable
        for i in 1..<t.count where mach <= t[i].0 {
            return t[i - 1].1 + (t[i].1 - t[i - 1].1) * (mach - t[i - 1].0) / (t[i].0 - t[i - 1].0)
        }
        return 0.97
    }

    private func buildShotTable() {
        let r = settings.shotSize.pelletMm / 2000
        let m = 11100 * 4 / 3 * Double.pi * r * r * r, area = Double.pi * r * r
        var v = settings.shotSpeed, t = 1 / v
        let dx = 0.1
        var tab = [0, t]
        if v > 0 {
            for k in 2...800 {
                let kk = 1.18 * BreakDistanceModel.sphereCd(v / 343) * area / (2 * m)
                let vn = v * exp(-kk * dx)
                t += dx * 2 / (v + vn)
                v = vn
                if k % 10 == 0 { tab.append(t) }
            }
        }
        shotTable = tab
    }

    /// Shot flight time to `x` metres, seconds.
    public func shotTime(_ x: Double) -> Double {
        if x <= 1 { return shotTable[1] * x }
        let j = min(Int(x.rounded(.down)), shotTable.count - 2)
        return shotTable[j] + (shotTable[j + 1] - shotTable[j]) * (x - Double(j))
    }

    /// Break distance in metres (to 0.1 m) for a shot at `timeSec` after the call, or nil when it cannot be computed.
    public func distance(scheme: Int, station: Int, direction d: Direction, timeSec: Double?) -> Double? {
        guard let tSec = timeSec, tSec.isFinite, let tr = Schemes.machine(scheme: scheme, station: station, direction: d) else { return nil }
        let V = settings.claySpeed, t0 = tSec - settings.releaseDelayMs / 1000
        guard t0 > 0, V > 0, settings.shotSpeed > 0 else { return nil }
        let S = BreakDistanceModel.self
        let ty = Double(3 - station) * S.stationSpacing + Double(1 - d.machineOffset) * S.machineSpacing
        let sy = Double(3 - station) * S.stationSpacing
        let az = Double(tr.signedAngle) * Double.pi / 180, ca = cos(az)
        let xe = S.tenMetres / ca
        let a = S.g * xe * xe / (2 * V * V)
        let c = tr.height - S.launchHeight + a
        let disc = xe * xe - 4 * a * c
        if disc < 0 { return nil }
        let el = atan((xe - disc.squareRoot()) / (2 * a))
        let vx = V * cos(el) * ca, vy = -V * cos(el) * sin(az), vz = V * sin(el)
        func dist(_ t: Double) -> Double {
            let x = vx * t + S.stationToTrench, y = ty + vy * t - sy
            let z = max(0, S.launchHeight + vz * t - 0.5 * S.g * t * t) - S.eyeHeight
            return (x * x + y * y + z * z).squareRoot()
        }
        var tb = t0
        for _ in 0..<30 { tb = t0 + shotTime(dist(tb)) }
        return (dist(tb) * 10).rounded(.toNearestOrAwayFromZero) / 10
    }
}

public extension Round {
    /// Which shot broke target `i`: 2 when a 2nd shot time is recorded, 1 with only a 1st shot time, 0 for a lost target or no time.
    func breakShot(at i: Int) -> Int {
        guard let s = results[i], s.isHit else { return 0 }
        return secondShot[i] != nil ? 2 : firstShot[i] != nil ? 1 : 0
    }
    /// Break distance of target `i`, metres, hits only.
    func breakDistance(at i: Int, model: BreakDistanceModel) -> Double? {
        let s = breakShot(at: i)
        guard s > 0, let d = directions[i] else { return nil }
        return model.distance(scheme: scheme, station: station(at: i), direction: d, timeSec: s == 1 ? firstShot[i] : secondShot[i])
    }
}
