import Foundation

/// Where the clay went: right, straight or left of the station.
/// Raw values match the web app's round document ("R", "S", "L"; "-" means not recorded).
public enum Direction: String, CaseIterable, Codable, Sendable, Hashable {
    case right = "R"
    case straight = "S"
    case left = "L"

    /// Machine offset inside a station's group of three: right 0, straight 1, left 2.
    public var machineOffset: Int {
        switch self { case .right: return 0; case .straight: return 1; case .left: return 2 }
    }
    public var name: String {
        switch self { case .right: return "Right"; case .straight: return "Straight"; case .left: return "Left" }
    }
    public var arrow: String {
        switch self { case .right: return "↗"; case .straight: return "↑"; case .left: return "↖" }
    }
    /// Entry order used by the web app for odds and prediction text: left, straight, right.
    public static let displayOrder: [Direction] = [.left, .straight, .right]
    /// Quota per station over 25 targets: 2 right, 1 straight, 2 left.
    public var quota: Int { self == .straight ? 1 : 2 }
}

/// Result of a target. Raw values match the round document ("G", "Y", "R").
public enum TargetResult: String, CaseIterable, Codable, Sendable, Hashable {
    /// Hit with the first shot.
    case hitFirst = "G"
    /// Hit with the second shot.
    case hitSecond = "Y"
    /// Lost.
    case lost = "R"

    public var isHit: Bool { self != .lost }
}
