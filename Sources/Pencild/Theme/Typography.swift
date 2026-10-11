import SwiftUI

/// Legacy type roles mapped onto the Pencil'd Plus Jakarta Sans scale.
struct DSTypography {
    static func displayHero() -> Font { PDFont.headlineXL }
    static func displayTitle() -> Font { PDFont.headlineLG }
    static func headlineSection() -> Font { PDFont.headlineMD }
    static func headlineCard() -> Font { PDFont.headlineSM }
    static func bodyStrong() -> Font { PDFont.jakarta(16, .semibold, relativeTo: .body) }
    static func bodyBase() -> Font { PDFont.bodyLG }
    static func bodyCompact() -> Font { PDFont.jakarta(14, .medium, relativeTo: .subheadline) }
    static func labelChip() -> Font { PDFont.labelMD }
    static func caption() -> Font { PDFont.bodySM }
    static func overlineConfidence() -> Font { PDFont.jakarta(11, .bold, relativeTo: .caption2) }
}
