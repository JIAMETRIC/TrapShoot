import SwiftUI

/// Spacing, radii, strokes, shadows, control sizes and motion, in points.
public enum BWMetrics {
    // Spacing scale (reference: 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 32, 48)
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s8: CGFloat = 32
    public static let s12: CGFloat = 48
    /// Screen side gutter (`.page-content` 20/24; phones 16).
    public static let gutter: CGFloat = 16

    // Radii (`--radius-md` 8, `--radius-lg` 14, `--radius-xl` 24, pills 999)
    public static let radiusXS: CGFloat = 4
    public static let radiusSM: CGFloat = 6
    public static let radiusMD: CGFloat = 8
    public static let radiusLG: CGFloat = 14
    public static let radiusXL: CGFloat = 24

    // Strokes
    public static let hairline: CGFloat = 1
    public static let stroke: CGFloat = 1.5
    /// Section label underline, grand total rule.
    public static let rule: CGFloat = 2
    /// KPI card top accent.
    public static let accentTop: CGFloat = 3
    /// Identity banner left accent.
    public static let accentLeft: CGFloat = 4

    // Control sizes. The reference uses 48 (inputs, submit), 40 (actions), 28-38 (icon buttons);
    // iOS needs 44 pt minimum tap targets, so icon buttons are 44.
    public static let controlHeight: CGFloat = 48
    public static let actionHeight: CGFloat = 44
    public static let iconButton: CGFloat = 44
    public static let statusDot: CGFloat = 8
    public static let featureBullet: CGFloat = 6

    /// Shadows: card `0 1px 3px 4%`, raised `0 4px 12px 6%`, sheet `0 20px 60px 15%`.
    public struct Shadow: Sendable {
        public let opacity: Double, radius: CGFloat, y: CGFloat
        public static let card = Shadow(opacity: 0.04, radius: 1.5, y: 1)
        public static let raised = Shadow(opacity: 0.06, radius: 6, y: 4)
        public static let sheet = Shadow(opacity: 0.15, radius: 30, y: 20)
    }
}

/// Motion: reference transitions, as SwiftUI animations.
public enum BWMotion {
    /// `--t-fast: 0.15s ease` (hover/pressed states).
    public static let fast = Animation.easeInOut(duration: 0.15)
    /// `0.2s` colour and opacity changes.
    public static let standard = Animation.easeInOut(duration: 0.2)
    /// `--t-sidebar: 0.28s cubic-bezier(0.4, 0, 0.2, 1)` layout changes.
    public static let layout = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.28)
    /// `vmBoxIn: 0.24s cubic-bezier(0.34, 1.10, 0.64, 1)` sheets and cards appearing (slight overshoot).
    public static let appear = Animation.spring(response: 0.3, dampingFraction: 0.8)
    /// Pressed scale of buttons (`transform: scale(0.99)`).
    public static let pressedScale: CGFloat = 0.98
    /// Pressed opacity of filled buttons (`opacity: 0.9`).
    public static let pressedOpacity: Double = 0.9
}

public extension View {
    func bwShadow(_ s: BWMetrics.Shadow) -> some View {
        shadow(color: Color.black.opacity(s.opacity), radius: s.radius, x: 0, y: s.y)
    }
}
