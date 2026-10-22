import SwiftUI
import UIKit

/// The palette. Names follow the roles in the reference CSS (bw-theme.css, login.css), values are the
/// zinc greys of login.css. Every token is dynamic: light appearance first, dark appearance second.
public enum BW {
    // MARK: raw scale (light values; the dark scale is the same list read from the other end)
    public static let black = Color(hex: 0x000000)
    public static let white = Color(hex: 0xFFFFFF)
    public static let grey50 = Color(hex: 0xFAFAFA)
    public static let grey100 = Color(hex: 0xF4F4F5)
    public static let grey200 = Color(hex: 0xE4E4E7)
    public static let grey300 = Color(hex: 0xD4D4D8)
    public static let grey400 = Color(hex: 0xA1A1AA)
    public static let grey500 = Color(hex: 0x71717A)
    public static let grey600 = Color(hex: 0x52525B)
    public static let grey700 = Color(hex: 0x3F3F46)
    public static let grey800 = Color(hex: 0x27272A)
    public static let grey900 = Color(hex: 0x18181B)

    // MARK: semantic, light / dark
    /// The "black" of the system: primary text, filled buttons, table headers, accents. White in dark mode.
    public static let ink = Color.dynamic(light: 0x000000, dark: 0xFFFFFF)
    /// Card and sheet background (`--clr-card-bg`).
    public static let paper = Color.dynamic(light: 0xFFFFFF, dark: 0x18181B)
    /// Page background (`--clr-surface`, grey-100).
    public static let surface = Color.dynamic(light: 0xF4F4F5, dark: 0x000000)
    /// Zebra rows and quiet boxes (grey-50).
    public static let surfaceAlt = Color.dynamic(light: 0xFAFAFA, dark: 0x27272A)
    /// Hairlines (`--clr-border`, grey-200).
    public static let border = Color.dynamic(light: 0xE4E4E7, dark: 0x3F3F46)
    /// Control borders and emphasised rules (grey-300).
    public static let borderStrong = Color.dynamic(light: 0xD4D4D8, dark: 0x52525B)
    /// Body text (grey-900).
    public static let text = Color.dynamic(light: 0x18181B, dark: 0xF4F4F5)
    /// Secondary text and field labels (grey-700).
    public static let textSecondary = Color.dynamic(light: 0x3F3F46, dark: 0xD4D4D8)
    /// Muted text, units, hints (`--clr-muted`, grey-500).
    public static let textMuted = Color.dynamic(light: 0x71717A, dark: 0xA1A1AA)
    /// Text on an ink fill.
    public static let onInk = Color.dynamic(light: 0xFFFFFF, dark: 0x000000)
    /// Translucent fills on ink panels (`rgba(255,255,255,0.10)` on black).
    public static func inkOverlay(_ opacity: Double) -> Color { onInk.opacity(opacity) }

    // MARK: status (the only colour in the system)
    public struct Status: Sendable {
        public let foreground: Color
        public let background: Color
        public let border: Color
        public let dot: Color
    }
    /// #065F46 on #ECFDF5, border #A7F3D0, dot #10B981.
    public static let success = Status(
        foreground: .dynamic(light: 0x065F46, dark: 0xA7F3D0),
        background: .dynamic(light: 0xECFDF5, dark: 0x10B981, darkOpacity: 0.15),
        border: .dynamic(light: 0xA7F3D0, dark: 0x10B981, darkOpacity: 0.35),
        dot: Color(hex: 0x10B981))
    /// #92400E on #FFFBEB, border #FDE68A, dot #F59E0B.
    public static let warning = Status(
        foreground: .dynamic(light: 0x92400E, dark: 0xFDE68A),
        background: .dynamic(light: 0xFFFBEB, dark: 0xF59E0B, darkOpacity: 0.15),
        border: .dynamic(light: 0xFDE68A, dark: 0xF59E0B, darkOpacity: 0.35),
        dot: Color(hex: 0xF59E0B))
    /// #991B1B on #FEF2F2, border #FECACA, dot #EF4444.
    public static let danger = Status(
        foreground: .dynamic(light: 0x991B1B, dark: 0xFECACA),
        background: .dynamic(light: 0xFEF2F2, dark: 0xEF4444, darkOpacity: 0.15),
        border: .dynamic(light: 0xFECACA, dark: 0xEF4444, darkOpacity: 0.35),
        dot: Color(hex: 0xEF4444))
    /// Grey pill (`.status-badge`, `.vm-badge-info`).
    public static let neutral = Status(foreground: textSecondary, background: surface, border: border, dot: textMuted)
    /// Ink pill (`.status-badge.dark`).
    public static let inkStatus = Status(foreground: onInk, background: ink, border: ink, dot: onInk)

    // MARK: shooting domain
    /// Hit with the first shot (G).
    public static let hitFirst = success
    /// Hit with the second shot (Y).
    public static let hitSecond = warning
    /// Lost (R).
    public static let lost = danger
    /// Destructive button (`.btn-danger-red` #DC3545).
    public static let destructive = Color.dynamic(light: 0xDC3545, dark: 0xEF4444)
}

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// A colour that follows the appearance: `light` hex in light mode, `dark` hex in dark mode.
    static func dynamic(light: UInt32, dark: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) -> Color {
        Color(uiColor: UIColor { trait in
            let isDark = trait.userInterfaceStyle == .dark
            return UIColor(hex: isDark ? dark : light, alpha: isDark ? darkOpacity : lightOpacity)
        })
    }
}

public extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}
