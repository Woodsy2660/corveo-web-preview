import SwiftUI

/*
 Corveo design tokens — the Userkind vocabulary, as Swift.

 Values mirror `src/components/tokens/tokens.css`, the token layer the reviewed web preview
 renders from (Desktop scale, refined against the Figma Properties panel 19 Aug 2026).
 `figma-tokens.css` (28 Aug) is the authoritative export and carries a Mobile scale that
 differs on spacing and type; adopting it is a design decision, and this file is the single
 place it lands when made.

 Rule (docs/01 §8): screens consume these tokens only. No raw hex, no raw points in a view.

 Chart colour is categorical only: it names a series (systolic/diastolic), fixed per series,
 never value-mapped. There are no threshold/zone/band colours here by design, and none may
 be added (SOW A.3.3).
 */

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255)
    }
}

enum CColor {
    // Surfaces
    static let surfaceAction = Color(hex: 0x000000)
    static let surfaceWhite = Color(hex: 0xffffff)
    static let surfaceColor1 = Color(hex: 0x3e4fb5)
    static let surfaceColor1Light = Color(hex: 0xb2caff)
    static let surfaceColor2 = Color(hex: 0x9e6850)
    static let surfaceColor3 = Color(hex: 0x1c7a8c)
    static let neutralLighter = Color(hex: 0xc9b4a5)
    static let neutralLight = Color(hex: 0xe5e5e5)
    static let neutralLightest = Color(hex: 0xf2ede9)
    /// Chart-step of surface-color-3, chroma raised so a translucent fill reads as colour.
    static let chartTeal = Color(hex: 0x00839b)

    // Text
    static let textHeading = Color(hex: 0x000000)
    static let textHeadingInverse = Color(hex: 0xffffff)
    static let textPrimary = Color(hex: 0x333333)
    static let textSecondary = Color(hex: 0x4d4d4d)
    static let textSecondaryInverse = Color(hex: 0xf2ede9)
    static let textTertiary = Color(hex: 0x808080)
    static let textDisabled = Color(hex: 0x999999)
    static let textLink = Color(hex: 0x3e4fb5)

    // Borders
    static let borderDefault = Color(hex: 0xcccccc)
    static let borderPrimary = Color(hex: 0x000000)

    // App semantic aliases (what screens actually consume)
    static let page = neutralLightest
    static let card = surfaceWhite
    static let action = surfaceAction
    static let actionInk = textHeadingInverse
    static let heading = textHeading
    static let ink = textPrimary
    static let inkSecondary = textSecondary
    static let inkTertiary = textTertiary
    static let inkDisabled = textDisabled
    static let hairline = borderDefault

    /// Series identities, fixed: systolic is always 1, diastolic always 2.
    static let chartSeries1 = surfaceColor1
    static let chartSeries2 = chartTeal
}

enum Spacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
    static let xl: CGFloat = 48
    static let xxl: CGFloat = 80
}

enum Radius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    /// Concentric with the device screen: the floating bar is inset 16 from a 44 corner.
    static let xl: CGFloat = 28
    static let round: CGFloat = 100
}

/// Type scale read off the Userkind Figma text styles. Sizes are points before Dynamic Type;
/// `CText` scales them with the reader's setting.
enum TypeScale {
    static let label: CGFloat = 12
    static let subheading: CGFloat = 14
    static let headingXL: CGFloat = 20
    static let heading2XL: CGFloat = 24
    static let heading3XL: CGFloat = 30
    static let heading4XL: CGFloat = 40
    static let bodySm: CGFloat = 14
    static let bodyBase: CGFloat = 16
    static let bodyLg: CGFloat = 18
    static let labelButton: CGFloat = 16
    static let specialLg: CGFloat = 40
    static let specialSm: CGFloat = 28
}

enum Motion {
    static let fast: Double = 0.16
    static let base: Double = 0.24
    private static let brandCurve = Animation.timingCurve(0.22, 1, 0.36, 1, duration: base)
    /// The Userkind brand curve, measured from the shipped site. Nil under Reduce Motion, so
    /// `withAnimation(Motion.brand)` and `.animation(Motion.brand, value:)` become immediate.
    static var brand: Animation? { UIAccessibility.isReduceMotionEnabled ? nil : brandCurve }
}

/// The two faces. Reckless (display serif) and Haffer (body sans) are licensed files that
/// have not been supplied; the system serif and SF stand in, exactly as the web preview
/// renders its fallbacks. Swap here when the files land.
enum CFontDesign {
    case display, body, mono
}

/// Dynamic Type aware font: the token size is the size at the default content size and
/// scales from there (rulebook §8.3 requires the largest accessibility sizes to work).
private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let design: CFontDesign
    private let weight: Font.Weight

    init(size: CGFloat, design: CFontDesign, weight: Font.Weight) {
        _size = ScaledMetric(wrappedValue: size)
        self.design = design
        self.weight = weight
    }

    func body(content: Content) -> some View {
        switch design {
        case .display:
            content
                .font(.system(size: size, weight: weight, design: .serif))
                .tracking(-0.02 * size)
        case .body:
            content
                .font(.system(size: size, weight: weight, design: .default))
        case .mono:
            content
                .font(.system(size: size, weight: weight, design: .monospaced))
        }
    }
}

extension View {
    /// Body sans at a token size.
    func cText(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFont(size: size, design: .body, weight: weight))
    }

    /// Display serif at a token size. Reserved for page titles and editorial display.
    func cDisplay(_ size: CGFloat) -> some View {
        modifier(ScaledFont(size: size, design: .display, weight: .regular))
    }

    func cMono(_ size: CGFloat) -> some View {
        modifier(ScaledFont(size: size, design: .mono, weight: .regular))
    }

    /// Userkind `Labels/label · 12/14`: the small contextual label above a title.
    func eyebrow() -> some View {
        self.cText(TypeScale.label, weight: .medium)
            .tracking(0.3)
            .foregroundStyle(CColor.inkTertiary)
    }
}
