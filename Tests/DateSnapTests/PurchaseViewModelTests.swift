import StoreKit
import Testing
@testable import DateSnap

@Suite("StoreKit-backed paywall state")
@MainActor
struct PurchaseViewModelTests {
    @Test("Missing StoreKit products have no fallback price and cannot be purchased")
    func missingProductsDisablePurchaseAndShowNoPrice() async {
        let purchases = PurchaseViewModel()
        await purchases.attach(EmptyProductService())

        #expect(purchases.displayPrice(.plus, annual: false).isEmpty)
        #expect(purchases.displayPrice(.premium, annual: true).isEmpty)
        #expect(purchases.monthlyEquivalent(.plus).isEmpty)
        #expect(!purchases.canPurchase(.plus, annual: false))
        #expect(!purchases.canPurchase(.premium, annual: true))
    }
}

@MainActor
private final class EmptyProductService: SubscriptionServiceProtocol {
    var currentTier: SubscriptionTier = .starter
    var isSubscribed: Bool { false }
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}
