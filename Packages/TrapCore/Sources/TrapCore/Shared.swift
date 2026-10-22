import Foundation

/// Sky as the round stores it ("sun", "part", "overcast", "rain").
public enum Sky: String, CaseIterable, Codable, Sendable {
    case sun, part, overcast, rain
    public var name: String {
        switch self { case .sun: return "Sun"; case .part: return "Part cloud"; case .overcast: return "Overcast"; case .rain: return "Rain" }
    }
    public static let names = allCases.map(\.name)
}

/// Wind as the round stores it ("calm", "light", "moderate", "strong").
public enum Wind: String, CaseIterable, Codable, Sendable {
    case calm, light, moderate, strong
    public var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    public static let names = allCases.map(\.name)
}

/// Arithmetic that must match the JavaScript original.
public enum JSMath {
    /// JavaScript `Math.round`: halves go toward positive infinity.
    public static func round(_ x: Double) -> Double { (x + 0.5).rounded(.down) }
    /// A JSON double as an Int, or nil when it is not finite or not safely representable.
    public static func safeInt(_ v: Double) -> Int? {
        guard v.isFinite, abs(v) < 9_007_199_254_740_992 else { return nil }
        return Int(v.rounded(.towardZero))
    }
}

/// Names shared by storage, recording and platform code. One place, so the Files app folder, the store name
/// and the display name never drift apart.
public enum AppConstants {
    public static let displayName = "TrapShoot"
    public static let productName = "TrapShooterPro"
    public static let bundleID = "com.mtajudeen.trapshooterpro"
    /// SwiftData store name (`<name>.store` in Application Support).
    public static let storeName = "TrapShooterPro"
    /// Folder under Documents; `RoundRecorder.folder` in ShotTimer uses the same name.
    public static let recordingsFolder = "Recordings"
}
