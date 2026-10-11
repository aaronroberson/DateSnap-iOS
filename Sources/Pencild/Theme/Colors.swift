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
    
    // MARK: - Semantic Tokens
    static let dsBackground = Color(hex: "050816")
    static let dsForeground = Color(hex: "F7F8FF")
    static let dsCard = Color(hex: "121834").opacity(0.72)
    static let dsCardElevated = Color(hex: "192144").opacity(0.85)
    static let dsCardForeground = Color(hex: "F7F8FF")
    
    static let dsPrimary = Color(hex: "7CFFEA") // Luminous Cyan
    static let dsPrimaryForeground = Color(hex: "07111F")
    
    static let dsSecondary = Color(hex: "5B7CFF") // Electric Blue / Indigo
    static let dsSecondaryForeground = Color(hex: "F7F8FF")
    
    static let dsMuted = Color.white.opacity(0.08)
    static let dsMutedForeground = Color(hex: "A8B0D4")
    
    static let dsBorder = Color(hex: "ADC3FF").opacity(0.18)
    static let dsBorderBright = Color(hex: "ADC3FF").opacity(0.35)
    
    static let dsAccent = Color(hex: "FF4FB3") // Luminous Magenta
    static let dsAccent2 = Color(hex: "FF8A3D") // Motion Orange
    
    static let dsSuccess = Color(hex: "46E39A")
    static let dsWarning = Color(hex: "FFBE55")
    static let dsError = Color(hex: "FF6B7A")
    static let dsInfo = Color(hex: "63B8FF")
    
    static let dsOverlay = Color(hex: "040816").opacity(0.78)
    static let dsGlassHighlight = Color.white.opacity(0.22)
    
    // MARK: - Gradients
    static let dsScanGradient = LinearGradient(
        colors: [Color(hex: "FF8A3D"), Color(hex: "FF4FB3"), Color(hex: "7B61FF")],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let dsBrandGradient = LinearGradient(
        colors: [
            Color(hex: "32C5FF"),
            Color(hex: "5B7CFF"),
            Color(hex: "9D4DFF"),
            Color(hex: "FF4FB3"),
            Color(hex: "FF8A3D")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let dsPrimaryActionGradient = LinearGradient(
        colors: [Color(hex: "7CFFEA"), Color(hex: "32C5FF")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let dsPrimaryAction = dsPrimaryActionGradient
    
    static let dsGoldGradient = LinearGradient(
        colors: [Color(hex: "FFBE55"), Color(hex: "FF8A3D")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
