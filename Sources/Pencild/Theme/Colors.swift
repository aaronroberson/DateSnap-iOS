import SwiftUI

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
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
            opacity: opacity * (Double(a) / 255)
        )
    }
    
    // MARK: - Legacy semantic aliases
    // Older views use these names; they resolve to the Pencil'd roles in
    // PencilTokens.swift so every screen shares one palette.
    static let dsBackground = pdSurface
    static let dsForeground = pdOnSurface
    static let dsCard = pdSurfaceContainer.opacity(0.85)
    static let dsCardElevated = pdSurfaceContainerHigh.opacity(0.92)
    static let dsSurfaceElevated = pdSurfaceContainerHigh
    static let dsCardForeground = pdOnSurface

    static let dsPrimary = pdPrimary
    static let dsPrimaryForeground = pdOnPrimaryFixed

    static let dsSecondary = pdSecondary
    static let dsSecondaryForeground = pdOnSurface

    static let dsMuted = pdSurfaceHighest.opacity(0.6)
    static let dsMutedForeground = pdOnSurfaceVariant

    static let dsBorder = pdSurfaceHighest.opacity(0.6)
    static let dsBorderBright = pdOutlineVariant

    static let dsAccent = pdTertiaryContainer
    static let dsAccent2 = pdPrimaryContainer

    static let dsSuccess = pdSuccess
    static let dsWarning = pdWarning
    static let dsError = pdError
    static let dsInfo = pdInfo

    static let dsOverlay = pdSurfaceLowest.opacity(0.85)
    static let dsGlassHighlight = Color.white.opacity(0.12)

    // MARK: - Gradients
    static let dsScanGradient = LinearGradient.pdSignature
    static let dsBrandGradient = LinearGradient.pdSignature
    static let dsPrimaryActionGradient = LinearGradient.pdAction
    static let dsPrimaryAction = dsPrimaryActionGradient
    static let dsGoldGradient = LinearGradient(
        colors: [.pdWarning, .pdPrimaryContainer],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
