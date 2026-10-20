import Foundation

public enum EntitlementRecordVerification: Sendable, Equatable {
    case verified
    case unverified
}

/// What StoreKit's subscription status says about a plan's renewal (a projection of
/// `Product.SubscriptionInfo.Status` and `RenewalInfo`).
public struct RenewalFacts: Sendable, Equatable {
    public enum State: Sendable, Equatable {
        case subscribed, inGracePeriod, inBillingRetry, expired, revoked
    }

    public let state: State
    public let willAutoRenew: Bool
    public let gracePeriodExpirationDate: Date?

    public init(state: State, willAutoRenew: Bool, gracePeriodExpirationDate: Date? = nil) {
        self.state = state
        self.willAutoRenew = willAutoRenew
        self.gracePeriodExpirationDate = gracePeriodExpirationDate
    }
}

/// A privacy-safe projection of StoreKit transaction state used by the entitlement resolver.
public struct SubscriptionEntitlementRecord: Sendable, Equatable {
    public let productID: String
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let verification: EntitlementRecordVerification
    /// Renewal status for this plan, when StoreKit supplied it. `nil` means unknown.
    public let renewal: RenewalFacts?

    public init(
        productID: String,
        expirationDate: Date?,
        revocationDate: Date?,
        verification: EntitlementRecordVerification,
        renewal: RenewalFacts? = nil
    ) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.verification = verification
        self.renewal = renewal
    }
}

public struct SubscriptionEntitlementResolution: Sendable, Equatable {
    public let snapshot: EntitlementSnapshot
    public let activeProductIDs: Set<String>
    public let verificationFailureCount: Int
    /// How long this entitlement may be trusted offline; `nil` when there is no paid entitlement.
    /// The service persists it so a later launch can seed from it.
    public let lease: SubscriptionLease?

    public init(
        snapshot: EntitlementSnapshot,
        activeProductIDs: Set<String>,
        verificationFailureCount: Int,
        lease: SubscriptionLease? = nil
    ) {
        self.snapshot = snapshot
        self.activeProductIDs = activeProductIDs
        self.verificationFailureCount = verificationFailureCount
        self.lease = lease
    }
}

public enum SubscriptionEntitlementResolver {
    public static func resolve(
        _ records: [SubscriptionEntitlementRecord],
        now: Date = Date(),
        provenance: EntitlementProvenance = .storeKit
    ) -> SubscriptionEntitlementResolution {
        var activeProductIDs: Set<String> = []
        var highestTier = SubscriptionTier.starter
        var verificationFailureCount = 0
        var best: SubscriptionLease?

        for record in records {
            guard record.verification == .verified else {
                verificationFailureCount += 1
                continue
            }
            guard record.revocationDate == nil, record.renewal?.state != .revoked else { continue }
            guard let product = SubscriptionCatalog.allProductIDs.first(where: { $0.rawValue == record.productID }) else {
                continue
            }

            // Apple's billing grace period keeps access after the period end while a failed
            // renewal payment is retried; the transaction itself still shows the old expiry.
            let graceEnd = record.renewal?.state == .inGracePeriod ? record.renewal?.gracePeriodExpirationDate : nil
            if let expirationDate = record.expirationDate, expirationDate <= now {
                guard let graceEnd, now < graceEnd else { continue }
            }

            let outlook: RenewalOutlook
            if product.period == .lifetime {
                outlook = .lifetime
            } else if let graceEnd {
                outlook = .inGrace(until: graceEnd)
            } else if let renewal = record.renewal {
                outlook = renewal.willAutoRenew ? .renewing : .endsAtExpiry
            } else {
                outlook = .unknown
            }
            let lease = SubscriptionLease(
                tier: product.tier,
                outlook: outlook,
                expirationDate: record.expirationDate,
                evaluatedAt: now
            )

            activeProductIDs.insert(product.rawValue)
            if product.tier.rank > highestTier.rank {
                highestTier = product.tier
            }
            // Keep the lease that grants the highest tier, then the longest access.
            if let current = best,
               (current.tier.rank, current.accessEnd) >= (lease.tier.rank, lease.accessEnd) {
                continue
            }
            best = lease
        }

        let state: EntitlementResolutionState = verificationFailureCount == 0 ? .verified : .unverified
        return SubscriptionEntitlementResolution(
            snapshot: EntitlementSnapshot(
                tier: verificationFailureCount == 0 ? highestTier : .starter,
                state: state,
                evaluatedAt: now,
                provenance: provenance
            ),
            activeProductIDs: verificationFailureCount == 0 ? activeProductIDs : [],
            verificationFailureCount: verificationFailureCount,
            lease: verificationFailureCount == 0 ? best : nil
        )
    }
}
