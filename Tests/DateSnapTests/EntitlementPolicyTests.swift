import Foundation
import Testing
@testable import DateSnap

@Suite("Feature access policy")
struct FeatureAccessPolicyTests {
    @Test("Every feature follows its verified tier matrix")
    func exhaustiveTierMatrix() {
        for feature in PremiumFeature.allCases {
            for tier in SubscriptionTier.allCases {
                let snapshot = EntitlementSnapshot.verified(tier, provenance: .testFixture)
                let decision = FeatureAccessPolicy.decision(for: feature, snapshot: snapshot)
                #expect(decision.isAllowed == tier.includes(feature))
            }
        }
    }

    @Test("Unresolved paid access always fails closed", arguments: [
        EntitlementResolutionState.checking,
        .unverified,
        .unavailable,
    ])
    func unresolvedStateFailsClosed(state: EntitlementResolutionState) {
        let snapshot = EntitlementSnapshot(
            tier: .premium,
            resolution: state,
            provenance: .testFixture
        )

        for feature in PremiumFeature.allCases {
            #expect(!FeatureAccessPolicy.decision(for: feature, snapshot: snapshot).isAllowed)
        }
    }

    @Test("Denials identify whether to wait, retry, or upgrade")
    func typedDenials() {
        #expect(FeatureAccessPolicy.decision(
            for: .documentImport,
            snapshot: .checking()
        ) == .denied(.entitlementChecking))
        #expect(FeatureAccessPolicy.decision(
            for: .documentImport,
            snapshot: .verified(.plus, provenance: .testFixture)
        ) == .denied(.requiresTier(.premium)))
    }
}

@Suite("Subscription product catalog")
struct SubscriptionCatalogTests {
    @Test("Catalog exactly matches the four StoreKit configuration products")
    func exactCatalog() {
        #expect(SubscriptionCatalog.productIdentifiers == [
            "com.datesnap.plus.monthly",
            "com.datesnap.plus.annual",
            "com.datesnap.premium.monthly",
            "com.datesnap.premium.annual",
        ])
        #expect(SubscriptionProduct.allCases.count == 4)
        #expect(SubscriptionCatalog.tier(for: "com.datesnap.plus.monthly") == .plus)
        #expect(SubscriptionCatalog.tier(for: "com.datesnap.plus.annual") == .plus)
        #expect(SubscriptionCatalog.tier(for: "com.datesnap.premium.monthly") == .premium)
        #expect(SubscriptionCatalog.tier(for: "com.datesnap.premium.annual") == .premium)
    }

    @Test("Unknown and lookalike identifiers never grant access")
    func unknownProductsDeny() {
        #expect(SubscriptionCatalog.tier(for: "com.datesnap.premium") == nil)
        #expect(SubscriptionCatalog.tier(for: "attacker.com.datesnap.premium.monthly") == nil)
        #expect(SubscriptionCatalog.tier(for: "") == nil)
    }
}

@Suite("Subscription entitlement resolver")
struct SubscriptionEntitlementResolverTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Active verified products resolve to the highest purchased tier")
    func activeProducts() {
        let result = SubscriptionEntitlementResolver.resolve([
            record(.plusAnnual, expires: now.addingTimeInterval(60)),
            record(.premiumMonthly, expires: now.addingTimeInterval(60)),
        ], now: now, provenance: .testFixture)

        #expect(result.snapshot == .verified(.premium, at: now, provenance: .testFixture))
        #expect(result.activeProductIDs.count == 2)
        #expect(result.verificationFailureCount == 0)
    }

    @Test("No purchases is a verified Starter result, not a loading state")
    func noPurchases() {
        let result = SubscriptionEntitlementResolver.resolve([], now: now, provenance: .testFixture)
        #expect(result.snapshot == .verified(.starter, at: now, provenance: .testFixture))
    }

    @Test("Expired, revoked, and unknown products never grant access")
    func inactiveProducts() {
        let result = SubscriptionEntitlementResolver.resolve([
            record(.premiumAnnual, expires: now),
            record(.premiumMonthly, expires: now.addingTimeInterval(60), revoked: now),
            SubscriptionEntitlementRecord(
                productID: "com.datesnap.premium.counterfeit",
                expirationDate: now.addingTimeInterval(60),
                revocationDate: nil,
                verification: .verified
            ),
        ], now: now, provenance: .testFixture)

        #expect(result.snapshot.tier == .starter)
        #expect(result.snapshot.resolution == .verified)
        #expect(result.activeProductIDs.isEmpty)
    }

    @Test("Any failed transaction verification fails the snapshot closed")
    func verificationFailure() {
        let result = SubscriptionEntitlementResolver.resolve([
            record(.premiumAnnual, expires: now.addingTimeInterval(60)),
            SubscriptionEntitlementRecord(
                productID: SubscriptionProduct.plusMonthly.rawValue,
                expirationDate: now.addingTimeInterval(60),
                revocationDate: nil,
                verification: .unverified
            ),
        ], now: now, provenance: .testFixture)

        #expect(result.snapshot.tier == .starter)
        #expect(result.snapshot.resolution == .unverified)
        #expect(result.activeProductIDs.isEmpty)
        #expect(result.verificationFailureCount == 1)
    }

    private func record(
        _ product: SubscriptionProduct,
        expires: Date?,
        revoked: Date? = nil
    ) -> SubscriptionEntitlementRecord {
        SubscriptionEntitlementRecord(
            productID: product.rawValue,
            expirationDate: expires,
            revocationDate: revoked,
            verification: .verified
        )
    }
}
