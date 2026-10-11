import SwiftUI

// MARK: - Card Modifier
/// Stitch card: tonal surface-container fill, 12pt radius, soft shadow and no
/// border. An explicit `borderColor` is kept as an accent outline for
/// highlighted or warning cards. Legacy radii above 16pt collapse to the
/// Stitch card radius so older call sites converge on one shape.
struct DSGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = PDRadius.card
    var elevated: Bool = false
    var borderColor: Color = .clear
    var borderWidth: CGFloat = 1

    private var radius: CGFloat { cornerRadius > PDRadius.plan ? PDRadius.card : cornerRadius }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(elevated ? Color.pdSurfaceContainerHigh.opacity(0.9) : Color.pdSurfaceContainer.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
            )
    }
}

extension View {
    func dsGlassCard(
        cornerRadius: CGFloat = PDRadius.card,
        elevated: Bool = false,
        borderColor: Color = .clear,
        borderWidth: CGFloat = 1
    ) -> some View {
        modifier(DSGlassCardModifier(
            cornerRadius: cornerRadius,
            elevated: elevated,
            borderColor: borderColor,
            borderWidth: borderWidth
        ))
    }

    /// Stitch canvas: deep surface with faint orange and violet ambient light.
    func dsScreenBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color.pdSurface
                    Circle()
                        .fill(Color.pdPrimaryContainer.opacity(0.10))
                        .blur(radius: 100)
                        .frame(width: 320, height: 320)
                        .offset(x: -130, y: -240)
                    Circle()
                        .fill(Color.pdSecondaryContainer.opacity(0.16))
                        .blur(radius: 110)
                        .frame(width: 300, height: 300)
                        .offset(x: 150, y: 220)
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - Confidence Pill
/// Confidence state always combines icon, label and color.
struct DSConfidencePill: View {
    let score: Int
    let label: String

    private var color: Color {
        if score >= 90 { return .pdSuccess }
        if score >= 70 { return .pdWarning }
        return .pdError
    }

    private var iconName: String {
        if score >= 90 { return "checkmark.seal.fill" }
        if score >= 70 { return "exclamationmark.triangle.fill" }
        return "xmark.octagon.fill"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(PDFont.jakarta(11, .bold, relativeTo: .caption2))
            Text("\(score)% \(label)")
                .font(PDFont.labelMD)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.15)))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Date Badge
struct DSDateBadge: View {
    let month: String
    let day: String
    var isSelected: Bool = false

    var body: some View {
        PDDateBadge(month: month, day: day, highlighted: isSelected)
    }
}

// MARK: - Primary CTA
/// Full-width gradient pill, the Stitch primary action.
struct DSPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    var minHeight: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PDFont.jakarta(16, .bold))
            .foregroundStyle(Color.pdOnPrimaryFixed)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(
                Capsule()
                    .fill(LinearGradient.pdAction)
                    .shadow(color: Color.pdPrimaryContainer.opacity(configuration.isPressed ? 0.15 : 0.3), radius: 14, y: 6)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1.0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Secondary CTA
/// Tonal pill on surface-container-high, the Stitch secondary action.
struct DSSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    var minHeight: CGFloat = 50

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PDFont.jakarta(16, .semibold))
            .foregroundStyle(Color.pdOnSurface)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .background(Capsule().fill(Color.pdSurfaceContainerHigh))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1.0))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
