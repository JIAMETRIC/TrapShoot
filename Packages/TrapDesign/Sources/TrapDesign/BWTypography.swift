import SwiftUI

/// Typography. The reference uses Bebas Neue (display), Inter (body) and a monospace for values.
/// Here: SF Pro condensed for display, SF Pro for body, SF Mono for values. All text styles scale with Dynamic Type.
public enum BWFont {
    /// Display: condensed, bold, uppercase with tracking. Replaces Bebas Neue.
    /// Reference sizes: page title 22, auth heading 28, card title 17, KPI value 28.
    public static func display(_ style: Font.TextStyle = .title2) -> Font {
        Font.system(style, design: .default).weight(.bold).width(.condensed)
    }
    /// Fixed-size display for hero numbers that should not grow without bound (scorecard, KPI).
    public static func display(size: CGFloat) -> Font {
        Font.system(size: size, weight: .bold).width(.condensed)
    }
    /// Heading in the body face: `.form-header h1` 28 / 700 / tracking -0.5.
    public static let heading = Font.system(.title, design: .default).weight(.bold)
    /// Modal and card headings: 18-20 / 700.
    public static let subheading = Font.system(.title3, design: .default).weight(.bold)
    /// Body: 14 Inter.
    public static let body = Font.system(.body)
    /// Secondary text: 13.
    public static let secondary = Font.system(.subheadline)
    /// Notes and footers: 12.
    public static let note = Font.system(.footnote)
    /// Field and KPI labels: 11 / 600 / uppercase / tracking 0.5-0.8. Apply with `.bwLabel()`.
    public static let label = Font.system(.caption2).weight(.semibold)
    /// Values that must line up: times, scores, ids. SF Mono with tabular digits.
    public static func value(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        Font.system(style, design: .monospaced).weight(weight).monospacedDigit()
    }
    /// Big monospaced figure: `.vm-kpi-value` 24 / `.vm-amount-value` 34.
    public static let valueLarge = Font.system(.title, design: .monospaced).weight(.bold).monospacedDigit()
    /// The timer readout (0.000). Fixed size so the digits never jump.
    public static func readout(size: CGFloat = 64) -> Font {
        Font.system(size: size, weight: .bold, design: .monospaced).monospacedDigit()
    }
}

/// Letter spacing in points, from the reference letter-spacing values.
public enum BWTracking {
    public static let display: CGFloat = 1.0       // page titles (1px); brand 2-2.5px
    public static let brand: CGFloat = 2.0
    public static let label: CGFloat = 0.6         // 0.5-0.8px uppercase labels
    public static let section: CGFloat = 1.0       // `.vm-section-label`
    public static let heading: CGFloat = -0.5      // 28px headings
}

public extension View {
    /// Uppercase, tracked, secondary small label (`.form-label`, `.kpi-label`, `.vm-field-label`).
    func bwLabel(color: Color = BW.textSecondary) -> some View {
        font(BWFont.label).textCase(.uppercase).tracking(BWTracking.label).foregroundStyle(color)
    }
    /// Display text style (`.page-title`, `.card-title`).
    func bwDisplay(_ style: Font.TextStyle = .title2) -> some View {
        font(BWFont.display(style)).textCase(.uppercase).tracking(BWTracking.display).foregroundStyle(BW.ink)
    }
}
