import SwiftUI

/// Pencil'd "Luminous Precision" tokens taken from the Stitch design system
/// (`.stitch/tokens/design-systems.json`). They are scoped to the splash
/// carousel and the Capture home screen; reconciling them with the app-wide
/// `ds*` tokens is tracked in docs/plans/2026-10-10-pencild-redesign-plan.md.
extension Color {
    static let pdSurface = Color(hex: "101127")
    static let pdSurfaceLowest = Color(hex: "0B0C22")
    static let pdSurfaceLow = Color(hex: "181930")
    static let pdSurfaceContainer = Color(hex: "1D1E34")
    static let pdSurfaceContainerHigh = Color(hex: "27283F")
    static let pdOnSurface = Color(hex: "E1E0FF")
    static let pdOnSurfaceVariant = Color(hex: "E0C0AF")
    static let pdOutlineVariant = Color(hex: "584235")
    static let pdPrimary = Color(hex: "FFB68B")
    static let pdOrange = Color(hex: "FF7A00")
    static let pdCoral = Color(hex: "FF5277")
    static let pdLavender = Color(hex: "DEB7FF")
    static let pdSurfaceHighest = Color(hex: "32334A")
    static let pdTertiaryContainer = Color(hex: "FF7288")
    /// Dark text for use on the orange/coral gradient (on-primary-fixed); white fails contrast there.
    static let pdOnPrimaryFixed = Color(hex: "321200")
}

extension LinearGradient {
    /// Signature Pencil'd gradient: orange to coral to lavender.
    static let pdSignature = LinearGradient(
        colors: [.pdOrange, .pdCoral, .pdLavender],
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension LinearGradient {
    /// Filled call-to-action gradient: orange to coral.
    static let pdAction = LinearGradient(
        colors: [.pdOrange, .pdCoral],
        startPoint: .leading,
        endPoint: .trailing
    )

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
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(Color.pdOnPrimaryFixed)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(LinearGradient.pdAction))
            .shadow(color: Color.pdOrange.opacity(0.45), radius: 16, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
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
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(highlighted ? Color.pdOnPrimaryFixed : Color.pdPrimary)
            Text(day)
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(highlighted ? Color.pdOnPrimaryFixed : Color.pdOnSurface)
        }
        .frame(width: 48, height: 54)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(highlighted ? AnyShapeStyle(LinearGradient.pdAction) : AnyShapeStyle(Color.pdSurfaceHighest))
        )
        .accessibilityElement(children: .combine)
    }
}
