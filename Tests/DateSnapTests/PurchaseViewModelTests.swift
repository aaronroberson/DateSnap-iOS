import StoreKit
import Testing
@testable import DateSnap

@Suite("StoreKit product availability")
@MainActor
struct PurchaseViewModelTests {
    @Test("Missing products show no price and disable purchase")
    func missingProductsFailClosed() async {
        let subscription = PurchaseSubscriptionService()
        let viewModel = PurchaseViewModel()
        await viewModel.attach(subscription)

        #expect(viewModel.displayPrice(.plus, annual: false).isEmpty)
        #expect(viewModel.displayPrice(.premium, annual: true).isEmpty)
        #expect(viewModel.monthlyEquivalent(.plus).isEmpty)
        #expect(!viewModel.canPurchase(.plus, annual: false))
        #expect(!viewModel.canPurchase(.premium, annual: true))
        #expect(await viewModel.purchase(.plus, annual: false) == nil)
        #expect(subscription.purchaseCount == 0)
    }

    @Test("StoreKit fetch errors stay visible and do not enable purchase")
    func offlineStoreKitFailsClosed() async {
        let subscription = PurchaseSubscriptionService(failsOffline: true)
        let viewModel = PurchaseViewModel()
        await viewModel.attach(subscription)

        #expect(viewModel.errorMessage?.localizedCaseInsensitiveContains("unavailable") == true)
        #expect(!viewModel.canPurchase(.premium, annual: true))
        #expect(await viewModel.purchase(.premium, annual: true) == nil)
        #expect(subscription.purchaseCount == 0)
    }
}

@MainActor
private final class PurchaseSubscriptionService: SubscriptionServiceProtocol {
    let failsOffline: Bool
    private(set) var purchaseCount = 0
    var currentTier: SubscriptionTier { .starter }
    var isSubscribed: Bool { false }

    init(failsOffline: Bool = false) {
        self.failsOffline = failsOffline
    }

    func fetchProducts() async throws -> [Product] {
        if failsOffline { throw StoreFailure.offline }
        return []
    }

    func purchase(product: Product) async throws -> SubscriptionTier {
        purchaseCount += 1
        return .plus
    }

    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

private enum StoreFailure: Error {
    case offline
}
