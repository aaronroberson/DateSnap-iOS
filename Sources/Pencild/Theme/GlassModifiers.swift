import SwiftUI

// MARK: - Glass Card Modifier
struct DSGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var elevated: Bool = false
    var borderColor: Color = Color.dsBorder
    var borderWidth: CGFloat = 1
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(elevated ? Color.dsCardElevated : Color.dsCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
                    .overlay(
                        // Subtle top-edge glass highlight
                        VStack {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.dsGlassHighlight, lineWidth: 1)
                                .frame(height: 2)
                                .padding(.horizontal, 2)
                            Spacer()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    )
            )
    }
}

// MARK: - View Extension for Styling
extension View {
    func dsGlassCard(
        cornerRadius: CGFloat = 20,
        elevated: Bool = false,
        borderColor: Color = Color.dsBorder,
        borderWidth: CGFloat = 1
    ) -> some View {
        modifier(DSGlassCardModifier(
            cornerRadius: cornerRadius,
            elevated: elevated,
            borderColor: borderColor,
            borderWidth: borderWidth
        ))
    }
    
    func dsScreenBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color.dsBackground.ignoresSafeArea()
                    
                    // Subtle ambient gradient orbs
                    Circle()
                        .fill(Color.dsSecondary.opacity(0.12))
                        .blur(radius: 90)
                        .frame(width: 320, height: 320)
                        .offset(x: -120, y: -220)
                    
                    Circle()
                        .fill(Color.dsAccent.opacity(0.08))
                        .blur(radius: 110)
                        .frame(width: 300, height: 300)
                        .offset(x: 140, y: 180)
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - Confidence Pill Component
struct DSConfidencePill: View {
    let score: Int
    let label: String
    
    var color: Color {
        if score >= 90 {
            return Color.dsSuccess
        } else if score >= 70 {
            return Color.dsWarning
        } else {
            return Color.dsError
        }
    }
    
    var iconName: String {
        if score >= 90 {
            return "checkmark.shield.fill"
        } else if score >= 70 {
            return "exclamationmark.triangle.fill"
        } else {
            return "xmark.octagon.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .bold))
            Text("\(score)% \(label)")
                .font(DSTypography.overlineConfidence())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.32), lineWidth: 1)
                )
        )
    }
}

// MARK: - Standard Date Badge
struct DSDateBadge: View {
    let month: String
    let day: String
    var isSelected: Bool = false
    
    var body: some View {
        VStack(spacing: 1) {
            Text(month.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsMutedForeground)
                .padding(.top, 4)
            
            Text(day)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.dsForeground)
                .padding(.bottom, 4)
        }
        .frame(width: 54, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.dsSecondary.opacity(0.24) : Color.dsCardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.dsPrimary.opacity(0.6) : Color.dsBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Primary Luminous CTA Button Style
struct DSPrimaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 52
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.bodyStrong())
            .foregroundStyle(Color.dsPrimaryForeground)
            .frame(maxWidth: .infinity)
            .frame(height: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.dsPrimaryActionGradient)
                    .shadow(color: Color.dsPrimary.opacity(configuration.isPressed ? 0.2 : 0.35), radius: 12, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Secondary Glass Button Style
struct DSSecondaryButtonStyle: ButtonStyle {
    var minHeight: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.bodyStrong())
            .foregroundStyle(Color.dsForeground)
            .frame(maxWidth: .infinity)
            .frame(height: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.dsCardElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.dsBorderBright, lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
