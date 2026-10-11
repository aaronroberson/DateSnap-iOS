import Foundation

public enum EntitlementRecordVerification: Sendable, Equatable {
    case verified
    case unverified
}

/// A privacy-safe projection of StoreKit transaction state used by the entitlement resolver.
public struct SubscriptionEntitlementRecord: Sendable, Equatable {
    public let productID: String
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let verification: EntitlementRecordVerification

    public init(
        productID: String,
        expirationDate: Date?,
        revocationDate: Date?,
        verification: EntitlementRecordVerification
    ) {
        self.productID = productID
        self.expirationDate = expirationDate
        self.revocationDate = revocationDate
        self.verification = verification
    }
}

public struct SubscriptionEntitlementResolution: Sendable, Equatable {
    public let snapshot: EntitlementSnapshot
    public let activeProductIDs: Set<String>
    public let verificationFailureCount: Int
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

        for record in records {
            guard record.verification == .verified else {
                verificationFailureCount += 1
                continue
            }
            guard record.revocationDate == nil else { continue }
            if let expirationDate = record.expirationDate, expirationDate <= now {
                continue
            }
            guard let product = SubscriptionCatalog.allProductIDs.first(where: { $0.rawValue == record.productID }) else {
                continue
            }

            activeProductIDs.insert(product.rawValue)
            if product.tier.rank > highestTier.rank {
                highestTier = product.tier
            }
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
            verificationFailureCount: verificationFailureCount
        )
    }
}
