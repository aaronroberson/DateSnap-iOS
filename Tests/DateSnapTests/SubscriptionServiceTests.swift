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

        do {
            _ = try SubscriptionService.checkVerified(result)
            Issue.record("Expected checkVerified to throw DateSnapError.subscription(.verificationFailed)")
        } catch DateSnapError.subscription(.verificationFailed) {
            // Expected path — an unverified StoreKit result must surface as verificationFailed.
        } catch {
            Issue.record("Expected DateSnapError.subscription(.verificationFailed), got \(error)")
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
}
