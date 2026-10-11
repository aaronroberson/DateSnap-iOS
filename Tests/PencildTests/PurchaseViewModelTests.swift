import Foundation
import StoreKit
import Testing
@testable import Pencild

@Suite("Purchase product pricing")
struct PurchaseViewModelTests {
    @Test("Missing products have no price and cannot be purchased")
    @MainActor
    func missingProductsDoNotExposeFallbackPricing() {
        let purchases = PurchaseViewModel()

        #expect(purchases.displayPrice(.plus, annual: true) == nil)
        #expect(purchases.displayPrice(.premium, annual: false) == nil)
        #expect(purchases.monthlyEquivalent(.plus) == nil)
        #expect(!purchases.canPurchase(.plus, annual: true))
        #expect(!purchases.canPurchase(.premium, annual: false))
    }

    @Test("StoreKit lookup failure remains visible and cannot be purchased")
    @MainActor
    func productLookupFailureIsVisible() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(OfflineSubscriptionService())

        #expect(purchases.errorMessage?.contains("Subscriptions are unavailable") == true)
        #expect(purchases.displayPrice(.plus, annual: true) == nil)
        #expect(!purchases.canPurchase(.plus, annual: true))
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
}

@MainActor
private struct OfflineSubscriptionService: SubscriptionServiceProtocol {
    var restoreError: PencildError? = nil
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
        return .starter
    }

    func updateCustomerProductStatus() async {}
}
