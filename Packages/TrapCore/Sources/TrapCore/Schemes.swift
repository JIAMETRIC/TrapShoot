import Foundation

/// One trap machine of an ISSF Olympic Trap scheme.
public struct TrapMachine: Equatable, Sendable {
    /// 1...15, machine number across the trench.
    public let number: Int
    /// "R", "L" or "C" (centre, angle 0).
    public let side: String
    /// Unsigned horizontal angle in degrees.
    public let angle: Int
    /// Signed angle: right positive, left negative.
    public let signedAngle: Int
    /// Height at 10 m, metres.
    public let height: Double
    /// Scheme table label, e.g. "45R", "0", "10L".
    public let label: String
}

/// The ten ISSF Olympic Trap schemes, exactly as the web app's SCHEME_SRC table.
public enum Schemes {
    public static let numbers: ClosedRange<Int> = 1...10
    public static let defaultScheme = 2

    private static let source: [Int: String] = [
        1: "30R 2.5,10R 1.5,30L 3|40R 1.7,5L 2,45L 2|45R 2,10L 3,45L 2.8|45R 2.3,10R 1.8,40L 1.6|30R 2,5L 1.5,35L 3",
        2: "45R 2.3,10R 1.5,20L 2|45R 1.5,0 2,45L 2.8|25R 2,0 3,45L 1.5|35R 2.2,10R 2.4,40L 1.5|30R 2.8,10L 1.5,45L 2",
        3: "45R 2.5,0 1.6,20L 3|35R 2.9,5L 1.8,45L 2|35R 2.5,10L 3,40L 3|40R 2,5L 2.5,30L 3|30R 2,0 1.8,30L 2.2",
        4: "30R 1.5,0 3,20L 3|30R 2,10L 1.5,45L 2.2|25R 3,5L 1.5,15L 1.8|40R 2.8,5L 1.5,35L 2.2|15R 3,10R 3,40L 1.7",
        5: "20R 1.8,0 3,25L 2.6|35R 3,0 1.6,35L 3|35R 2.3,5L 1.8,35L 2.3|40R 3,0 2.3,40L 2|25R 1.8,5L 2.5,45L 1.6",
        6: "45R 1.9,0 2.8,30L 3|40R 1.5,0 1.6,40L 2|35R 2,0 3,45L 2|45R 2.3,5R 2,40L 3|25R 2.4,0 1.75,35L 1.8",
        7: "40R 3,0 1.5,35L 1.5|45R 2,5R 2.2,45L 3|40R 1.5,5R 1.9,25L 2.6|20R 1.8,0 3,30L 3|35R 2.5,0 3,40L 2.2",
        8: "40R 3,5L 3,15L 2.2|30R 2,5L 2,35L 1.8|40R 2,5R 1.5,35L 2.5|45R 1.5,5R 2,25L 3|15R 1.5,0 1.5,45L 1.6",
        9: "30R 1.6,0 1.5,15L 2|20R 2.4,5L 3,35L 2|45R 2,5L 1.5,35L 1.5|45R 1.6,0 2.8,45L 2|25R 3,5R 1.5,20L 3",
        10: "45R 2.25,0 1.75,25L 2|35R 1.8,0 3,40L 2.25|40R 3,5R 1.8,45L 3|45R 2,10L 2.5,35L 1.5|15R 1.8,10R 2,45L 1.5"
    ]

    /// 15 machines per scheme, machine 1 first.
    public static let table: [Int: [TrapMachine]] = {
        var out: [Int: [TrapMachine]] = [:]
        for (k, text) in source {
            var list: [TrapMachine] = []
            for group in text.split(separator: "|") {
                for item in group.split(separator: ",") {
                    let parts = item.trimmingCharacters(in: .whitespaces).split(separator: " ")
                    let d = String(parts[0]), h = Double(parts[1]) ?? 0
                    let n = list.count + 1
                    if d == "0" {
                        list.append(TrapMachine(number: n, side: "C", angle: 0, signedAngle: 0, height: h, label: "0"))
                    } else {
                        let side = String(d.suffix(1)), a = Int(d.dropLast()) ?? 0
                        list.append(TrapMachine(number: n, side: side, angle: a, signedAngle: side == "R" ? a : -a, height: h, label: d))
                    }
                }
            }
            out[k] = list
        }
        return out
    }()

    public static func isValid(_ scheme: Int) -> Bool { table[scheme] != nil }

    /// The machine that throws `direction` from `station` (1...5) in `scheme`.
    public static func machine(scheme: Int, station: Int, direction: Direction) -> TrapMachine? {
        guard let list = table[scheme], (1...5).contains(station) else { return nil }
        return list[3 * (station - 1) + direction.machineOffset]
    }
}
