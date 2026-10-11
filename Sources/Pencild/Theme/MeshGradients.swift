import SwiftUI

// MARK: - Mesh Gradient Support (iOS 18+)

/// Mesh gradient styles for premium design system
/// Not availability-gated: the style itself uses no iOS 18 APIs — only the views
/// that render `MeshGradient` from it are.
public enum MeshGradientStyle {
    case premiumAccent
    case glassEffect
    case successGlow
    case warningGlow
    
    var colors: [Color] {
        switch self {
        case .premiumAccent:
            return [
                .dsPrimary,
                Color(hex: "#7CFFEA").opacity(0.8),
                Color(hex: "#4FD1C5").opacity(0.6),
                .dsAccent.opacity(0.7)
            ]
        case .glassEffect:
            return [
                .white.opacity(0.1),
                .white.opacity(0.05),
                .dsPrimary.opacity(0.2),
                .clear
            ]
        case .successGlow:
            return [
                Color.green.opacity(0.6),
                Color(hex: "#7CFFEA").opacity(0.4),
                .white.opacity(0.2)
            ]
        case .warningGlow:
            return [
                Color.orange.opacity(0.6),
                Color(hex: "#FFB347").opacity(0.4),
                .white.opacity(0.2)
            ]
        }
    }
    
    var width: Int {
        switch self {
        case .premiumAccent: return 4
        case .glassEffect: return 3
        case .successGlow: return 3
        case .warningGlow: return 3
        }
    }
    
    var height: Int {
        switch self {
        case .premiumAccent: return 4
        case .glassEffect: return 3
        case .successGlow: return 3
        case .warningGlow: return 3
        }
    }

    /// Normalized point grid for the style's dimensions, row-major.
    /// `MeshGradient` requires exactly `width * height` points.
    var gridPoints: [SIMD2<Float>] {
        guard width > 1, height > 1 else { return [SIMD2<Float>(0.5, 0.5)] }
        return (0..<height).flatMap { row in
            (0..<width).map { col in
                SIMD2(Float(col) / Float(width - 1), Float(row) / Float(height - 1))
            }
        }
    }

    /// The style's palette cycled to fill the full `width * height` grid —
    /// `MeshGradient` requires `colors.count == points.count`.
    var gridColors: [Color] {
        let palette = colors
        guard !palette.isEmpty else { return [] }
        return (0..<(width * height)).map { palette[$0 % palette.count] }
    }
}

// MARK: - Mesh Gradient View Modifiers

@available(iOS 18.0, *)
public struct MeshGradientModifier: ViewModifier {
    let style: MeshGradientStyle
    
    public func body(content: Content) -> some View {
        content
            .background(
                MeshGradient(
                    width: style.width,
                    height: style.height,
                    points: style.gridPoints,
                    colors: style.gridColors
                )
                .blur(radius: 20)
                .opacity(0.7)
            )
    }
}

@available(iOS 18.0, *)
public struct PremiumMeshBorder: ViewModifier {
    let isActive: Bool
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                MeshGradient(
                                    width: 3,
                                    height: 3,
                                    points: [
                                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                                    ],
                                    colors: [
                                        .dsPrimary,
                                        .dsAccent,
                                        Color(hex: "#7CFFEA"),
                                        .dsAccent,
                                        .dsPrimary,
                                        Color(hex: "#FF4FB3"),
                                        Color(hex: "#7CFFEA"),
                                        Color(hex: "#FF4FB3"),
                                        .dsPrimary
                                    ]
                                ),
                                lineWidth: 3
                            )
                            .blur(radius: 1)
                    }
                }
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a mesh gradient background (iOS 18+ only)
    @ViewBuilder
    public func meshGradientBackground(_ style: MeshGradientStyle) -> some View {
        if #available(iOS 18.0, *) {
            self.modifier(MeshGradientModifier(style: style))
        } else {
            self.background(
                LinearGradient(
                    colors: style.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.7)
            )
        }
    }
    
    /// Apply a premium mesh border (iOS 18+ only)
    @ViewBuilder
    public func premiumMeshBorder(isActive: Bool = true) -> some View {
        if #available(iOS 18.0, *), isActive {
            self.modifier(PremiumMeshBorder(isActive: isActive))
        } else {
            self
        }
    }
    
    /// Premium card with mesh gradient effects
    @ViewBuilder
    public func premiumCardStyle(isPremium: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dsCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.dsBorder.opacity(0.3), lineWidth: 1)
                    )
            )
            .premiumMeshBorder(isActive: isPremium)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}