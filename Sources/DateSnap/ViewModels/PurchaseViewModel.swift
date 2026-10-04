import Foundation
import StoreKit
import SwiftUI

// MARK: - Purchase View Model
/// Drives the paywalls: loads StoreKit products, purchases, and restores through `SubscriptionServiceProtocol`.
@MainActor
final class PurchaseViewModel: ObservableObject {
    enum Plan: Sendable {
        case plus, premium

        var monthlyID: String { self == .plus ? "com.datesnap.plus.monthly" : "com.datesnap.premium.monthly" }
        var annualID: String { self == .plus ? "com.datesnap.plus.annual" : "com.datesnap.premium.annual" }
        var tier: SubscriptionTier { self == .plus ? .plus : .premium }
    }

    private var subscription: SubscriptionServiceProtocol?

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String? = nil

    /// Connects the view model to the app's subscription service (from `@Environment(\.services)`) and loads products.
    func attach(_ subscription: SubscriptionServiceProtocol) async {
        self.subscription = subscription
        await loadProducts()
    }

    var currentTier: SubscriptionTier { subscription?.currentTier ?? .starter }

    func loadProducts() async {
        guard let subscription, products.isEmpty else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await subscription.fetchProducts()
            products = Dictionary(fetched.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            errorMessage = "Subscriptions are unavailable right now. Check your connection and try again."
        }
    }

    func product(_ plan: Plan, annual: Bool) -> Product? {
        products[annual ? plan.annualID : plan.monthlyID]
    }

    /// Localized price from the App Store. `nil` means the product is unavailable.
    func displayPrice(_ plan: Plan, annual: Bool) -> String? {
        product(plan, annual: annual)?.displayPrice
    }

    /// Annual price expressed per month, e.g. "$3.33".
    func monthlyEquivalent(_ plan: Plan) -> String? {
        guard let annual = product(plan, annual: true) else { return nil }
        return (annual.price / 12).formatted(annual.priceFormatStyle)
    }

    func canPurchase(_ plan: Plan, annual: Bool) -> Bool {
        !isLoadingProducts && !isPurchasing && product(plan, annual: annual) != nil
    }

    /// Free-trial length from the product's introductory offer, if it has one.
    func trialDescription(_ plan: Plan, annual: Bool) -> String? {
        guard let offer = product(plan, annual: annual)?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let period = offer.period
        switch period.unit {
        case .day: return period.value == 7 ? "1-week" : "\(period.value)-day"
        case .week: return "\(period.value)-week"
        case .month: return "\(period.value)-month"
        case .year: return "\(period.value)-year"
        @unknown default: return nil
        }
    }

    /// Purchases the plan. Returns the resulting tier, or nil if cancelled / failed (with `errorMessage` set on failure).
    func purchase(_ plan: Plan, annual: Bool) async -> SubscriptionTier? {
        guard let subscription, let product = product(plan, annual: annual) else {
            errorMessage = "This plan isn't available yet. Please try again in a moment."
            return nil
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            return try await subscription.purchase(product: product)
        } catch DateSnapError.subscription(.purchaseCancelled) {
            return nil
        } catch DateSnapError.subscription(.purchasePending) {
            errorMessage = "Your purchase is pending approval. It will unlock automatically once approved."
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Restores purchases via `AppStore.sync()`. Returns the restored tier, or nil on failure.
    func restore() async -> SubscriptionTier? {
        guard let subscription else { return nil }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            return try await subscription.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Legal Links
enum DateSnapLinks {
    static let privacyPolicy: URL = {
        guard let url = URL(string: "https://datesnap.app/privacy") else {
            preconditionFailure("Invalid Privacy Policy URL")
        }
        return url
    }()

    static let support: URL = {
        guard let url = URL(string: "https://datesnap.app/support") else {
            preconditionFailure("Invalid Support URL")
        }
        return url
    }()

    /// Apple's standard auto-renewable subscription EULA.
    static let termsOfUse: URL = {
        guard let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") else {
            preconditionFailure("Invalid Terms of Use URL")
        }
        return url
    }()
}
