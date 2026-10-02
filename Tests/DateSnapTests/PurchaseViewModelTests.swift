import Foundation
import StoreKit
import Testing
@testable import DateSnap

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
}

@MainActor
private struct OfflineSubscriptionService: SubscriptionServiceProtocol {
    var currentTier: SubscriptionTier { .starter }
    var isSubscribed: Bool { false }

    func fetchProducts() async throws -> [Product] {
        throw URLError(.notConnectedToInternet)
    }

    func purchase(product: Product) async throws -> SubscriptionTier {
        .starter
    }

    func restorePurchases() async throws -> SubscriptionTier {
        .starter
    }

    func updateCustomerProductStatus() async {}
}
