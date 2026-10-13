import Foundation
import StoreKit
import Testing
@testable import Pencild

@Suite("Purchase product pricing and recovery edge cases")
struct PurchaseViewModelTests {
    @Test("Missing products have no price and cannot be purchased")
    @MainActor
    func missingProductsDoNotExposeFallbackPricing() {
        let purchases = PurchaseViewModel()

        #expect(purchases.displayPrice(.plus, .annual) == nil)
        #expect(purchases.displayPrice(.premium, .monthly) == nil)
        #expect(purchases.monthlyEquivalent(.plus) == nil)
        #expect(!purchases.canPurchase(.plus, .annual))
        #expect(!purchases.canPurchase(.premium, .monthly))
    }

    @Test("StoreKit lookup failure remains visible and cannot be purchased")
    @MainActor
    func productLookupFailureIsVisible() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService())

        #expect(purchases.errorMessage?.contains("Subscriptions are unavailable") == true)
        #expect(purchases.displayPrice(.plus, .annual) == nil)
        #expect(!purchases.canPurchase(.plus, .annual))
    }

    @Test("Unavailable product purchase produces truthful visible recovery message")
    @MainActor
    func unavailableProductPurchaseError() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService())

        let result = await purchases.purchase(.plus, .annual)
        #expect(result == nil)
        #expect(purchases.errorMessage == "This plan isn't available yet. Please try again in a moment.")
    }

    @Test("Cancelled restore closes without an error or entitlement change")
    @MainActor
    func cancelledRestoreIsQuiet() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService(restoreError: .subscription(.purchaseCancelled)))

        #expect(await purchases.restore() == nil)
        #expect(purchases.errorMessage == nil)
        #expect(!purchases.isPurchasing)
        #expect(purchases.currentTier == .starter)
    }

    @Test("Failed restore offers recovery without claiming verification failure")
    @MainActor
    func restoreFailureIsActionable() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService(restoreError: .subscription(.restoreFailed)))

        #expect(await purchases.restore() == nil)
        #expect(purchases.errorMessage?.contains("Couldn't restore purchases") == true)
        #expect(purchases.errorMessage?.contains("cryptographic") == false)
        #expect(!purchases.isPurchasing)
        #expect(purchases.currentTier == .starter)
    }

    @Test("Empty restore returns starter tier so UI can surface truthful not-found copy")
    @MainActor
    func emptyRestoreReturnsStarter() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService(restoredTier: .starter))

        let restored = await purchases.restore()
        #expect(restored == .starter)
        #expect(purchases.errorMessage == nil)
    }

    @Test("Successful restore returns upgraded tier")
    @MainActor
    func successfulRestoreReturnsUpgradedTier() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService(restoredTier: .plus))

        let restored = await purchases.restore()
        #expect(restored == .plus)
        #expect(purchases.errorMessage == nil)
    }
}

@MainActor
private struct OfflineSubscriptionService: SubscriptionServiceProtocol {
    var restoreError: PencildError? = nil
    var restoredTier: SubscriptionTier = .starter
    var currentTier: SubscriptionTier { .starter }
    var isSubscribed: Bool { false }
    var entitlementSnapshot: EntitlementSnapshot {
        EntitlementSnapshot(tier: currentTier, state: .verified, evaluatedAt: testAnchor, provenance: .none)
    }

    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}

    func fetchProducts() async throws -> [Product] {
        throw URLError(.notConnectedToInternet)
    }

    func purchase(product: Product) async throws -> SubscriptionTier {
        .starter
    }

    func restorePurchases() async throws -> SubscriptionTier {
        if let restoreError { throw restoreError }
        return restoredTier
    }

    func updateCustomerProductStatus() async {}
}
