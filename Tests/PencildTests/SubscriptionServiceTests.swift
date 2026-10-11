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
}
