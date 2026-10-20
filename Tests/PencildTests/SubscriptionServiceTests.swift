import Foundation
import StoreKit
import Testing
@testable import Pencild

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
            DummyTransaction(productID: "com.pencild.premium.monthly", revocationDate: nil),
            VerificationResult<DummyTransaction>.VerificationError.invalidSignature
        )

        do {
            _ = try SubscriptionService.checkVerified(result)
            Issue.record("Expected checkVerified to throw PencildError.subscription(.verificationFailed)")
        } catch PencildError.subscription(.verificationFailed) {
            // Expected path — an unverified StoreKit result must surface as verificationFailed.
        } catch {
            Issue.record("Expected PencildError.subscription(.verificationFailed), got \(error)")
        }
    }

    @Test("checkVerified returns payload when given .verified")
    func checkVerifiedVerifiedSucceeds() throws {
        let dummy = DummyTransaction(productID: "com.pencild.plus.monthly", revocationDate: nil)
        let result = VerificationResult<DummyTransaction>.verified(dummy)

        let extracted = try SubscriptionService.checkVerified(result)
        #expect(extracted.productID == "com.pencild.plus.monthly")
        #expect(extracted.revocationDate == nil)
    }

    // MARK: - Entitlement Cache

    @Test("EntitlementCache round-trips a SubscriptionLease")
    func entitlementCacheRoundTrip() {
        let suite = UserDefaults(suiteName: "entitlement-cache-test-\(UUID().uuidString)")!
        EntitlementCache.setDefaults(suite)
        defer {
            EntitlementCache.clear()
            EntitlementCache.useStandardDefaults()
        }

        let original = SubscriptionLease(tier: .plus, outlook: .inGrace(until: Date(timeIntervalSince1970: 1_100_000)), expirationDate: Date(timeIntervalSince1970: 1_000_000), evaluatedAt: Date(timeIntervalSince1970: 999_999))
        EntitlementCache.save(original)
        let loaded = EntitlementCache.load()
        #expect(loaded == original)
    }

    @Test("EntitlementCache.clear removes the stored value")
    func entitlementCacheClear() {
        let suite = UserDefaults(suiteName: "entitlement-cache-test-\(UUID().uuidString)")!
        EntitlementCache.setDefaults(suite)
        defer {
            EntitlementCache.clear()
            EntitlementCache.useStandardDefaults()
        }

        EntitlementCache.save(SubscriptionLease(tier: .premium, outlook: .lifetime, expirationDate: nil, evaluatedAt: Date()))
        #expect(EntitlementCache.load() != nil)
        EntitlementCache.clear()
        #expect(EntitlementCache.load() == nil)
    }

    @Test("a verified purchase is granted immediately and cached")
    @MainActor
    func verifiedPurchaseGrantsImmediately() {
        let suite = UserDefaults(suiteName: "entitlement-cache-test-\(UUID().uuidString)")!
        EntitlementCache.setDefaults(suite)
        defer { EntitlementCache.useStandardDefaults() }

        let service = SubscriptionService(observesTransactionUpdates: false)
        service.applyVerified(
            SubscriptionEntitlementRecord(
                productID: "com.pencild.plus.annual",
                expirationDate: Date().addingTimeInterval(365 * 86_400),
                revocationDate: nil,
                verification: .verified
            ),
            provenance: .purchase
        )
        #expect(service.currentTier == .plus)
        #expect(service.entitlementSnapshot.state == .verified)
        #expect(EntitlementCache.load()?.tier == .plus)
    }
}
