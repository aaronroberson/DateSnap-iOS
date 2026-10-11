import SwiftUI

struct DSTypography {
    // MARK: - Display Scale (Sora style: rounded / crisp geometric feel)
    static func displayHero() -> Font {
        .system(size: 34, weight: .heavy, design: .rounded)
    }
    
    static func displayTitle() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func headlineSection() -> Font {
        .system(size: 22, weight: .bold, design: .rounded)
    }
    
    static func headlineCard() -> Font {
        .system(size: 19, weight: .semibold, design: .rounded)
    }
    
    static func bodyStrong() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }
    
    static func bodyBase() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }
    
    static func bodyCompact() -> Font {
        .system(size: 14, weight: .medium, design: .default)
    }
    
    static func labelChip() -> Font {
        .system(size: 13, weight: .semibold, design: .default)
    }
    
    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }
    
    static func overlineConfidence() -> Font {
        .system(size: 11, weight: .bold, design: .rounded)
    }
}
