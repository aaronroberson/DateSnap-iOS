import Foundation
import StoreKit
import Testing
@testable import DateSnap

@Suite("SubscriptionService Tests")
struct SubscriptionServiceTests {

    // MARK: - Dummy Transaction Type for Testing
    private struct DummyTransaction: Sendable {
        let productID: String
        let revocationDate: Date?
    }

    // MARK: - checkVerified Tests
    @Test("checkVerified throws verificationFailed when given .unverified")
    func checkVerifiedUnverifiedThrows() {
        let result = VerificationResult<DummyTransaction>.unverified(
            DummyTransaction(productID: "com.datesnap.premium.monthly", revocationDate: nil),
            VerificationResult<DummyTransaction>.VerificationError.invalidSignature
        )

        #expect(throws: DateSnapError.subscription(.verificationFailed)) {
            try SubscriptionService.checkVerified(result)
        }
    }

    @Test("checkVerified returns payload when given .verified")
    func checkVerifiedVerifiedSucceeds() throws {
        let dummy = DummyTransaction(productID: "com.datesnap.plus.monthly", revocationDate: nil)
        let result = VerificationResult<DummyTransaction>.verified(dummy)

        let extracted = try SubscriptionService.checkVerified(result)
        #expect(extracted.productID == "com.datesnap.plus.monthly")
        #expect(extracted.revocationDate == nil)
    }

    // MARK: - Tier Determination Tests
    @Test("determineTier maps premium product IDs to .premium")
    func determineTierPremium() {
        #expect(SubscriptionService.determineTier(from: ["com.datesnap.premium.monthly"]) == .premium)
        #expect(SubscriptionService.determineTier(from: ["com.datesnap.premium.annual"]) == .premium)
        #expect(SubscriptionService.determineTier(from: ["com.datesnap.premium.monthly", "com.datesnap.plus.monthly"]) == .premium)
    }

    @Test("determineTier maps plus product IDs to .plus")
    func determineTierPlus() {
        #expect(SubscriptionService.determineTier(from: ["com.datesnap.plus.monthly"]) == .plus)
        #expect(SubscriptionService.determineTier(from: ["com.datesnap.plus.annual"]) == .plus)
    }

    @Test("determineTier maps empty or unrecognized product IDs to .starter")
    func determineTierStarter() {
        #expect(SubscriptionService.determineTier(from: []) == .starter)
        #expect(SubscriptionService.determineTier(from: ["unknown.product.id"]) == .starter)
    }

    // MARK: - Entitlement Processing Tests
    @Test("processEntitlements includes active unrevoked transactions and excludes revoked ones")
    func processEntitlementsRevocationHandling() {
        let activeDummy = DummyTransaction(productID: "com.datesnap.plus.monthly", revocationDate: nil)
        let revokedDummy = DummyTransaction(productID: "com.datesnap.premium.monthly", revocationDate: Date())

        let results: [VerificationResult<DummyTransaction>] = [
            .verified(activeDummy),
            .verified(revokedDummy)
        ]

        let purchasedIDs = SubscriptionService.processEntitlements(
            results,
            productID: { $0.productID },
            revocationDate: { $0.revocationDate }
        )

        #expect(purchasedIDs.contains("com.datesnap.plus.monthly"))
        #expect(!purchasedIDs.contains("com.datesnap.premium.monthly"))
        #expect(purchasedIDs.count == 1)
    }

    @Test("processEntitlements handles mixed verified and unverified sequence, continuing loop after unverified throw")
    func processEntitlementsMixedSequence() {
        let unverifiedDummy = DummyTransaction(productID: "com.datesnap.premium.monthly", revocationDate: nil)
        let verifiedDummy = DummyTransaction(productID: "com.datesnap.plus.annual", revocationDate: nil)

        let results: [VerificationResult<DummyTransaction>] = [
            .unverified(unverifiedDummy, VerificationResult<DummyTransaction>.VerificationError.invalidSignature),
            .verified(verifiedDummy)
        ]

        let purchasedIDs = SubscriptionService.processEntitlements(
            results,
            productID: { $0.productID },
            revocationDate: { $0.revocationDate }
        )

        #expect(!purchasedIDs.contains("com.datesnap.premium.monthly"))
        #expect(purchasedIDs.contains("com.datesnap.plus.annual"))
        #expect(purchasedIDs.count == 1)

        let tier = SubscriptionService.determineTier(from: purchasedIDs)
        #expect(tier == .plus)
    }
}
