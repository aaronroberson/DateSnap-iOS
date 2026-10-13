import Foundation
import Testing
@testable import Pencild

@Suite("Feature access policy")
@MainActor
struct FeatureAccessPolicyTests {
    @Test("Every feature follows its verified tier matrix")
    func exhaustiveTierMatrix() {
        for feature in PremiumFeature.allCases {
            for tier in SubscriptionTier.allCases {
                let snapshot = EntitlementSnapshot.verified(tier, provenance: .storeKit)
                let decision = FeatureAccessPolicy.decision(for: feature, snapshot: snapshot)
                if tier.includes(feature) {
                    #expect(decision == .allowed)
                } else {
                    #expect(decision == .denied(.requiresTier(feature.requiredTier)))
                }
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
            state: state,
            provenance: .storeKit
        )

        let expectedReason: FeatureAccessDenyReason
        switch state {
        case .checking: expectedReason = .checkingEntitlements
        case .unverified: expectedReason = .unverified
        case .unavailable: expectedReason = .unavailable
        case .verified:
            Issue.record("The test only covers unresolved states")
            return
        }
        for feature in PremiumFeature.allCases {
            #expect(FeatureAccessPolicy.decision(for: feature, snapshot: snapshot) == .denied(expectedReason))
        }
    }

    @Test("Denials identify whether to wait, retry, or upgrade")
    func typedDenials() {
        #expect(FeatureAccessPolicy.decision(
            for: .documentImport,
            snapshot: .checking()
        ) == .denied(.checkingEntitlements))
        #expect(FeatureAccessPolicy.decision(
            for: .documentImport,
            snapshot: .verified(.plus, provenance: .storeKit)
        ) == .denied(.requiresTier(.premium)))
    }
}

@Suite("Subscription product catalog")
struct SubscriptionCatalogTests {
    @Test("Catalog exactly matches the six StoreKit configuration products")
    func exactCatalog() {
        #expect(SubscriptionCatalog.productIdentifiers == [
            "com.pencild.plus.monthly",
            "com.pencild.plus.annual",
            "com.pencild.plus.lifetime",
            "com.pencild.premium.monthly",
            "com.pencild.premium.annual",
            "com.pencild.premium.lifetime",
        ])
        #expect(SubscriptionCatalog.allProductIDs.count == 6)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.plus.monthly") == .plus)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.plus.annual") == .plus)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.plus.lifetime") == .plus)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.premium.monthly") == .premium)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.premium.annual") == .premium)
        #expect(SubscriptionCatalog.tier(for: "com.pencild.premium.lifetime") == .premium)
    }

    @Test("Unknown and lookalike identifiers never grant access")
    func unknownProductsDeny() {
        #expect(SubscriptionCatalog.tier(for: "com.pencild.premium") == nil)
        #expect(SubscriptionCatalog.tier(for: "attacker.com.pencild.premium.monthly") == nil)
        #expect(SubscriptionCatalog.tier(for: "") == nil)
    }
}

@Suite("Subscription entitlement resolver")
struct SubscriptionEntitlementResolverTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Active verified products resolve to the highest purchased tier")
    func activeProducts() {
        let result = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.annual", expires: now.addingTimeInterval(60)),
            record("com.pencild.premium.monthly", expires: now.addingTimeInterval(60)),
        ], now: now, provenance: .storeKit)

        #expect(result.snapshot == .verified(.premium, at: now, provenance: .storeKit))
        #expect(result.activeProductIDs.count == 2)
        #expect(result.verificationFailureCount == 0)
    }

    @Test("No purchases is a verified Starter result, not a loading state")
    func noPurchases() {
        let result = SubscriptionEntitlementResolver.resolve([], now: now, provenance: .storeKit)
        #expect(result.snapshot == .verified(.starter, at: now, provenance: .storeKit))
    }

    @Test("Expired, revoked, and unknown products never grant access")
    func inactiveProducts() {
        let result = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.premium.annual", expires: now),
            record("com.pencild.premium.monthly", expires: now.addingTimeInterval(60), revoked: now),
            SubscriptionEntitlementRecord(
                productID: "com.pencild.premium.counterfeit",
                expirationDate: now.addingTimeInterval(60),
                revocationDate: nil,
                verification: .verified
            ),
        ], now: now, provenance: .storeKit)

        #expect(result.snapshot.tier == .starter)
        #expect(result.snapshot.state == .verified)
        #expect(result.activeProductIDs.isEmpty)
    }

    @Test("Any failed transaction verification fails the snapshot closed")
    func verificationFailure() {
        let result = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.premium.annual", expires: now.addingTimeInterval(60)),
            SubscriptionEntitlementRecord(
                productID: "com.pencild.plus.monthly",
                expirationDate: now.addingTimeInterval(60),
                revocationDate: nil,
                verification: .unverified
            ),
        ], now: now, provenance: .storeKit)

        #expect(result.snapshot.tier == .starter)
        #expect(result.snapshot.state == .unverified)
        #expect(result.activeProductIDs.isEmpty)
        #expect(result.verificationFailureCount == 1)
    }

    private func record(
        _ productID: String,
        expires: Date?,
        revoked: Date? = nil
    ) -> SubscriptionEntitlementRecord {
        SubscriptionEntitlementRecord(
            productID: productID,
            expirationDate: expires,
            revocationDate: revoked,
            verification: .verified
        )
    }
}
