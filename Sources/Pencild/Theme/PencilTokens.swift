import SwiftUI

/// Pencil'd "Luminous Precision" design tokens, taken from the Stitch design
/// system (`.stitch/Brand-Onboarding/Home-Screen/DESIGN.md`). This file is the
/// single source of truth; the legacy `ds*` names in `Colors.swift` alias these.
extension Color {
    // Surfaces
    static let pdSurface = Color(hex: "101127")
    static let pdSurfaceLowest = Color(hex: "0B0C22")
    static let pdSurfaceLow = Color(hex: "181930")
    static let pdSurfaceContainer = Color(hex: "1D1E34")
    static let pdSurfaceContainerHigh = Color(hex: "27283F")
    static let pdSurfaceHighest = Color(hex: "32334A")
    static let pdSurfaceBright = Color(hex: "36374F")

    // Content
    static let pdOnSurface = Color(hex: "E1E0FF")
    static let pdOnSurfaceVariant = Color(hex: "E0C0AF")
    static let pdOutline = Color(hex: "A78B7C")
    static let pdOutlineVariant = Color(hex: "584235")

    // Accent roles
    static let pdPrimary = Color(hex: "FFB68B")
    static let pdOnPrimary = Color(hex: "522300")
    static let pdPrimaryContainer = Color(hex: "FF7A00")
    static let pdSecondary = Color(hex: "DEB7FF")
    static let pdSecondaryContainer = Color(hex: "670FAC")
    static let pdTertiary = Color(hex: "FFB2BA")
    static let pdTertiaryContainer = Color(hex: "FF7288")
    static let pdError = Color(hex: "FFB4AB")

    // Gradient stops
    static let pdOrange = Color(hex: "FF7A00")
    static let pdCoral = Color(hex: "FF5277")
    static let pdLavender = Color(hex: "DEB7FF")
    /// Dark text for use on the orange/coral gradient (on-primary-fixed); white fails contrast there.
    static let pdOnPrimaryFixed = Color(hex: "321200")

    // Status (always paired with an icon and label). Success/info are lifted
    // from the source palette so small labels retain contrast on tonal cards.
    static let pdSuccess = Color(hex: "34D399")
    static let pdWarning = Color(hex: "FFB800")
    static let pdInfo = Color(hex: "7FB2FF")
}

/// Spacing scale from the Stitch spec (4/6/8/16/24/32/48, 16pt margins).
enum PDSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let margin: CGFloat = 16
}

/// Corner radii from the Stitch spec.
enum PDRadius {
    static let tile: CGFloat = 8
    static let card: CGFloat = 12
    static let plan: CGFloat = 16
}

/// Plus Jakarta Sans scaled with Dynamic Type.
enum PDFont {
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        let face: String
        switch weight {
        case .black, .heavy: face = "ExtraBold"
        case .bold: face = "Bold"
        case .semibold: face = "SemiBold"
        case .medium: face = "Medium"
        default: face = "Regular"
        }
        return .custom("PlusJakartaSans-\(face)", size: size, relativeTo: style)
    }

    static let display = jakarta(38, .heavy, relativeTo: .largeTitle)
    static let headlineXL = jakarta(30, .bold, relativeTo: .largeTitle)
    static let headlineLG = jakarta(28, .bold, relativeTo: .title)
    static let headlineMD = jakarta(22, .semibold, relativeTo: .title2)
    static let headlineSM = jakarta(18, .semibold, relativeTo: .title3)
    static let bodyLG = jakarta(16, .regular, relativeTo: .body)
    static let bodyMD = jakarta(14, .regular, relativeTo: .subheadline)
    static let bodySM = jakarta(12, .regular, relativeTo: .footnote)
    static let labelLG = jakarta(14, .semibold, relativeTo: .subheadline)
    static let labelMD = jakarta(12, .semibold, relativeTo: .caption)
    /// Use with `.textCase(.uppercase)` and `.tracking(0.6)`.
    static let labelSM = jakarta(10, .bold, relativeTo: .caption2)
}

extension LinearGradient {
    /// Signature filled action gradient from the Stitch screens.
    static let pdSignature = LinearGradient(
        colors: [.pdOrange, .pdTertiaryContainer, .pdLavender],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// The warmer orange/coral/lavender treatment used for brand headlines.
    static let pdHeadline = LinearGradient(
        colors: [.pdOrange, .pdCoral, .pdLavender],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension LinearGradient {
    static let pdAction = pdSignature

    /// Soft warm wash for selected chips, selected date badges and highlighted cards.
    static let pdSelected = LinearGradient(
        colors: [Color.pdOrange.opacity(0.28), Color.pdCoral.opacity(0.16)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Highlight card surface (today's events, hero cards).
    static let pdHighlightCard = LinearGradient(
        colors: [Color.pdSurfaceContainerHigh, Color.pdSurfaceContainer],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Full-width gradient call-to-action with a warm glow.
struct PDGradientButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PDFont.jakarta(16, .bold))
            .foregroundStyle(Color.pdOnPrimaryFixed)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(LinearGradient.pdAction))
            .shadow(color: Color.pdOrange.opacity(0.45), radius: 16, y: 6)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.92 : 1) : 0.45)
    }
}

/// Refined checkmark: gradient disc with a heavy dark check.
struct PDCheckmark: View {
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.55, weight: .heavy))
            .foregroundStyle(Color.pdOnPrimaryFixed)
            .frame(width: size, height: size)
            .background(Circle().fill(LinearGradient.pdAction))
            .accessibilityHidden(true)
    }
}

/// Month/day badge in the Pencil'd style.
struct PDDateBadge: View {
    let month: String
    let day: String
    var highlighted: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text(month.uppercased())
                .font(PDFont.labelSM)
                .tracking(0.8)
                .foregroundStyle(highlighted ? Color.pdOnPrimaryFixed : Color.pdPrimary)
            Text(day)
                .font(PDFont.jakarta(20, .heavy, relativeTo: .title3))
                .foregroundStyle(highlighted ? Color.pdOnPrimaryFixed : Color.pdOnSurface)
        }
        .frame(width: 48, height: 54)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(highlighted ? AnyShapeStyle(LinearGradient.pdAction) : AnyShapeStyle(Color.pdSurfaceHighest))
        )
        .accessibilityElement(children: .combine)
    }
}
