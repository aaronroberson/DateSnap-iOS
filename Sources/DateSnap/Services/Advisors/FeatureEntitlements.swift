import Foundation

// MARK: - Feature Entitlements
/// Which subscription tier unlocks each convenience feature. Correctness features — scanning, evidence,
/// on-device interpretation of a single scan, manual review and saving — are available to every tier and
/// deliberately absent from this list. Runtime capability (e.g. Apple Intelligence) is checked separately:
/// an unsupported device is never sold a capability it cannot run.
public enum PremiumFeature: String, CaseIterable, Sendable {
    /// New screenshots surface on Home automatically.
    case automaticScreenshotDetection
    /// Recent screenshots are ranked by how likely they are to contain an event.
    case likelyEventTriage
    /// PDF and Files import with multi-page batch scanning.
    case documentImport
    /// Archive-wide grouping of possible duplicate events.
    case duplicateClusters
    /// Suggested reminder plans including RSVP-deadline reminders.
    case advancedReminderPlans

    public var requiredTier: SubscriptionTier {
        switch self {
        case .automaticScreenshotDetection, .likelyEventTriage: return .plus
        case .documentImport, .duplicateClusters, .advancedReminderPlans: return .premium
        }
    }

    /// One-line value statement shown at the point the user tries the feature.
    public var upgradeReason: String {
        switch self {
        case .automaticScreenshotDetection: return "Plus surfaces new event screenshots automatically."
        case .likelyEventTriage: return "Plus highlights which screenshots look like events."
        case .documentImport: return "Premium scans PDFs and files, every page."
        case .duplicateClusters: return "Premium groups likely duplicates across your archive."
        case .advancedReminderPlans: return "Premium adds deadline reminders and tailored alert plans."
        }
    }
}

extension SubscriptionTier {
    private var rank: Int {
        switch self {
        case .starter: return 0
        case .plus: return 1
        case .premium: return 2
        }
    }

    public func includes(_ feature: PremiumFeature) -> Bool {
        rank >= feature.requiredTier.rank
    }
}
