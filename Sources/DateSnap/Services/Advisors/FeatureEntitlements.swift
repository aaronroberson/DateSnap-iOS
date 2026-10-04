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

// MARK: - Entitlement Resolution State

/// The current resolution state of an entitlement check. Used by the single authoritative policy
/// to make allow/deny decisions.
public enum EntitlementResolutionState: String, Sendable, CaseIterable, Equatable {
    case checking
    case verified
    case unverified
    case unavailable
}

// MARK: - Entitlement Provenance

/// Where an entitlement snapshot originated from. Used to distinguish between launch-time checks,
/// ongoing transaction updates, purchase events, restores, and scene-active refreshes.
public enum EntitlementProvenance: String, Sendable, CaseIterable, Equatable {
    case none
    case storeKit
    case launch
    case transactionUpdate
    case purchase
    case restore
    case sceneActivation
}

// MARK: - Entitlement Snapshot

/// A privacy-safe projection of StoreKit transaction state used by the entitlement resolver and
/// the single-authorization policy. Carries tier, resolution state, evaluation timestamp, and
/// provenance so that UI and operation boundaries can make consistent access decisions.
public struct EntitlementSnapshot: Sendable, Equatable {
    public var tier: SubscriptionTier
    public var state: EntitlementResolutionState
    public var evaluatedAt: Date
    public var provenance: EntitlementProvenance

    public static func == (lhs: EntitlementSnapshot, rhs: EntitlementSnapshot) -> Bool {
        lhs.tier == rhs.tier && lhs.state == rhs.state && lhs.evaluatedAt == rhs.evaluatedAt && lhs.provenance == rhs.provenance
    }

    public init(
        tier: SubscriptionTier,
        state: EntitlementResolutionState,
        evaluatedAt: Date = Date(),
        provenance: EntitlementProvenance
    ) {
        self.tier = tier
        self.state = state
        self.evaluatedAt = evaluatedAt
        self.provenance = provenance
    }

    public static func checking(at date: Date = Date()) -> Self {
        .init(tier: .starter, state: .checking, evaluatedAt: date, provenance: .none)
    }

    public static func verified(
        _ tier: SubscriptionTier,
        at date: Date = Date(),
        provenance: EntitlementProvenance = .storeKit
    ) -> Self {
        .init(tier: tier, state: .verified, evaluatedAt: date, provenance: provenance)
    }
}

// MARK: - Feature Access Decision

/// The result of evaluating a feature against an entitlement snapshot via the single authoritative
/// policy. UI preflight and operation boundaries both query this type; it is never computed from
/// raw tier Booleans or ad hoc flags.
public enum FeatureAccessDecision: Sendable, Equatable {
    case allowed
    case denied(FeatureAccessDenyReason)

    var documentImportMessage: String {
        switch self {
        case .allowed:
            return ""
        case .denied(.checkingEntitlements):
            return "DateSnap is still checking your subscription. Please try again shortly."
        case .denied(.unverified), .denied(.unavailable):
            return "DateSnap could not verify your subscription. Please try again."
        case .denied(.requiresTier):
            return PremiumFeature.documentImport.upgradeReason
        }
    }
}

// MARK: - Feature Access Deny Reason

/// Typed reason for why a feature access was denied. Each case is specific enough that the UI can
/// translate it into an appropriate message or paywall presentation without exposing implementation
/// details.
public enum FeatureAccessDenyReason: Sendable, Equatable {
    case requiresTier(SubscriptionTier)
    case checkingEntitlements
    case unverified
    case unavailable
}

// MARK: - Feature Access Policy

/// The single pure authorization policy used by presentation preflight and protected operations.
/// All protected side effects must query this policy (not inline tier checks or Boolean flags).
/// Deny-by-default: paid features are allowed only when `state == .verified && snapshot.tier.includes(feature)`.
/// `.checking` / `.unverified` / `.unavailable` deny all paid features (per the audit's "model
/// checking/unverified/unavailable separately, deny by default"). Since every `PremiumFeature` requires
/// plus/premium, unresolved states deny everything.
@MainActor
public enum FeatureAccessPolicy {
    /// The definitive decision for a given entitlement snapshot and feature.
    /// Deny-by-default: paid features are allowed only when
    /// `state == .verified && snapshot.tier.includes(feature)`.
    /// `.checking` / `.unverified` / `.unavailable` deny all paid features.
    public static func decision(
        for feature: PremiumFeature,
        snapshot: EntitlementSnapshot
    ) -> FeatureAccessDecision {
        switch snapshot.state {
        case .checking:
            return .denied(.checkingEntitlements)
        case .unverified:
            return .denied(.unverified)
        case .unavailable:
            return .denied(.unavailable)
        case .verified:
            return snapshot.tier.includes(feature)
                ? .allowed
                : .denied(.requiresTier(feature.requiredTier))
        }
    }
}

// MARK: - Entitlement Providing Protocol

/// A privacy-safe projection of StoreKit transaction state used by the entitlement resolver and
/// the single-authorization policy. Carries tier, resolution state, evaluation timestamp, and
/// provenance so that UI and operation boundaries can make consistent access decisions.
@MainActor
public protocol EntitlementProviding: Sendable {
    var entitlementSnapshot: EntitlementSnapshot { get }
    func refreshEntitlements(_ provenance: EntitlementProvenance) async
}

// MARK: - Subscription Product ID

/// A typed, hashable identifier for a StoreKit product. Raw values are the exact product
/// identifiers from `DateSnap.storekit` (the four known IDs). Tier and annual status are
/// derived from the raw value, not inferred via substring matching.
public struct SubscriptionProductID: Sendable, Hashable {
    public let rawValue: String
    public var tier: SubscriptionTier
    public var isAnnual: Bool

    public init(rawValue: String, tier: SubscriptionTier, isAnnual: Bool) {
        self.rawValue = rawValue
        self.tier = tier
        self.isAnnual = isAnnual
    }
}

// MARK: - Subscription Catalog

/// The typed, exact product catalog for the four known StoreKit identifiers. Centralizes the
/// product-ID-to-tier mapping so that no duplicate/substring-based inference exists anywhere
/// in the codebase (addressing F-05). Unknown product IDs resolve to no entitlement.
public enum SubscriptionCatalog {
    /// The four known product identifiers from `DateSnap.storekit`.
    public static let allProductIDs: Set<SubscriptionProductID> = [
        SubscriptionProductID(rawValue: "com.datesnap.plus.monthly", tier: .plus, isAnnual: false),
        SubscriptionProductID(rawValue: "com.datesnap.plus.annual", tier: .plus, isAnnual: true),
        SubscriptionProductID(rawValue: "com.datesnap.premium.monthly", tier: .premium, isAnnual: false),
        SubscriptionProductID(rawValue: "com.datesnap.premium.annual", tier: .premium, isAnnual: true),
    ]

    /// The complete set of product identifiers.
    public static let productIdentifiers: Set<String> = Set(allProductIDs.map(\.rawValue))

    /// Exact tier mapping for a given product identifier. Returns `nil` for unknown identifiers.
    public static func tier(for productID: String) -> SubscriptionTier? {
        allProductIDs.first(where: { $0.rawValue == productID })?.tier
    }

    /// Whether a product identifier is known.
    public static func contains(_ productID: String) -> Bool {
        allProductIDs.contains { $0.rawValue == productID }
    }
}

// MARK: - Subscription Tier Helpers (extension)

extension SubscriptionTier {
    /// Monotonic rank: Starter=0, Plus=1, Premium=2. Used by `PremiumFeature.includes`.
    var rank: Int {
        switch self {
        case .starter: return 0
        case .plus: return 1
        case .premium: return 2
        }
    }

    /// Returns `true` if this tier includes the given feature (i.e., its rank is >= the feature's
    /// required tier's rank). Implements the monotonic hierarchy: Premium includes Plus features,
    /// and Plus includes features whose required tier is Plus.
    public func includes(_ feature: PremiumFeature) -> Bool {
        rank >= feature.requiredTier.rank
    }
}
