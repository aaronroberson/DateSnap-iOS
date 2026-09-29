import Foundation
import Testing
@testable import DateSnap

@Suite("Cross-service advisors")
struct AdvisorTests {
    @Test("Entitlements gate convenience features only, by tier")
    func entitlements() {
        #expect(!SubscriptionTier.starter.includes(.automaticScreenshotDetection))
        #expect(SubscriptionTier.plus.includes(.automaticScreenshotDetection))
        #expect(SubscriptionTier.plus.includes(.likelyEventTriage))
        #expect(!SubscriptionTier.plus.includes(.documentImport))
        #expect(SubscriptionTier.premium.includes(.advancedReminderPlans))
        #expect(PremiumFeature.allCases.allSatisfy { SubscriptionTier.premium.includes($0) })
    }
}
