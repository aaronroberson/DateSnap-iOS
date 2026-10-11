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
}

extension LinearGradient {
    /// Signature Pencil'd gradient: orange to coral to lavender.
    static let pdSignature = LinearGradient(
        colors: [.pdOrange, .pdCoral, .pdLavender],
        startPoint: .leading,
        endPoint: .trailing
    )
}
