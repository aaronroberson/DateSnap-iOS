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

public enum EntitlementResolutionState: String, Sendable, Equatable {
    case checking
    case verified
    case unverified
    case unavailable
}

public enum EntitlementProvenance: String, Sendable, Equatable {
    case storeKit
    case testFixture
    case none
}

public struct EntitlementSnapshot: Sendable, Equatable {
    public let tier: SubscriptionTier
    public let resolution: EntitlementResolutionState
    public let evaluatedAt: Date
    public let provenance: EntitlementProvenance

    public init(
        tier: SubscriptionTier,
        resolution: EntitlementResolutionState,
        evaluatedAt: Date = Date(),
        provenance: EntitlementProvenance
    ) {
        self.tier = tier
        self.resolution = resolution
        self.evaluatedAt = evaluatedAt
        self.provenance = provenance
    }

    public static func checking(at date: Date = Date()) -> Self {
        .init(tier: .starter, resolution: .checking, evaluatedAt: date, provenance: .none)
    }

    public static func verified(
        _ tier: SubscriptionTier,
        at date: Date = Date(),
        provenance: EntitlementProvenance = .storeKit
    ) -> Self {
        .init(tier: tier, resolution: .verified, evaluatedAt: date, provenance: provenance)
    }
}

public enum FeatureAccessDenial: Sendable, Equatable, Error {
    case entitlementChecking
    case entitlementUnverified
    case entitlementUnavailable
    case requiresTier(SubscriptionTier)
}

public enum FeatureAccessDecision: Sendable, Equatable {
    case allowed
    case denied(FeatureAccessDenial)

    public var isAllowed: Bool {
        self == .allowed
    }
}

/// The single pure authorization policy used by presentation preflight and protected operations.
public enum FeatureAccessPolicy {
    public static func decision(
        for feature: PremiumFeature,
        snapshot: EntitlementSnapshot
    ) -> FeatureAccessDecision {
        switch snapshot.resolution {
        case .checking:
            return .denied(.entitlementChecking)
        case .unverified:
            return .denied(.entitlementUnverified)
        case .unavailable:
            return .denied(.entitlementUnavailable)
        case .verified:
            guard snapshot.tier.includes(feature) else {
                return .denied(.requiresTier(feature.requiredTier))
            }
            return .allowed
        }
    }
}

@MainActor
public protocol EntitlementProviding: Sendable {
    var entitlementSnapshot: EntitlementSnapshot { get }
    func refreshEntitlements() async
}

extension SubscriptionTier {
    var rank: Int {
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
