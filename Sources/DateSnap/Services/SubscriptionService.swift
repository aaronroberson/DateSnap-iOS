import Foundation
import OSLog
import StoreKit

// MARK: - Subscription Entitlement Tiers
public enum SubscriptionTier: String, CaseIterable, Identifiable, Sendable {
    case starter = "Starter"     // Free: manual review, single scans
    case plus = "Plus"           // Screenshot & photo auto-detection
    case premium = "Premium"     // Full automation, files/PDF import, unlimited history

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .starter: return "DateSnap Starter"
        case .plus: return "DateSnap Plus"
        case .premium: return "DateSnap Premium"
        }
    }

    public var badgeText: String {
        switch self {
        case .starter: return "FREE"
        case .plus: return "PLUS"
        case .premium: return "PRO"
        }
    }
}

// MARK: - Subscription Service Protocol
@MainActor
public protocol SubscriptionServiceProtocol: Sendable {
    var currentTier: SubscriptionTier { get }
    var isSubscribed: Bool { get }
    func fetchProducts() async throws -> [Product]
    func purchase(product: Product) async throws -> SubscriptionTier
    func restorePurchases() async throws -> SubscriptionTier
    func updateCustomerProductStatus() async
}

// MARK: - Production Subscription Service (StoreKit 2)
@MainActor
public final class SubscriptionService: ObservableObject, SubscriptionServiceProtocol {
    public static let shared = SubscriptionService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.datesnap.app", category: "SubscriptionService")

    @Published public private(set) var currentTier: SubscriptionTier = .starter
    @Published public private(set) var availableProducts: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading: Bool = false

    public var isSubscribed: Bool {
        currentTier != .starter
    }

    public static let productIdentifiers: Set<String> = [
        "com.datesnap.plus.monthly",
        "com.datesnap.plus.annual",
        "com.datesnap.premium.monthly",
        "com.datesnap.premium.annual"
    ]

    private var updateListenerTask: Task<Void, Error>? = nil

    public init() {
        updateListenerTask = listenForTransactions()

        Task {
            await updateCustomerProductStatus()
            _ = try? await fetchProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self?.updateCustomerProductStatus()
                    await transaction.finish()
                } catch {
                    Self.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Fetch Products
    public func fetchProducts() async throws -> [Product] {
        isLoading = true
        defer { isLoading = false }

        do {
            let products = try await Product.products(for: Self.productIdentifiers)
            let sorted = products.sorted { $0.price < $1.price }
            self.availableProducts = sorted
            return sorted
        } catch {
            throw DateSnapError.subscription(.productNotFound(error.localizedDescription))
        }
    }

    // MARK: - Purchase
    public func purchase(product: Product) async throws -> SubscriptionTier {
        isLoading = true
        defer { isLoading = false }

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw DateSnapError.subscription(.purchaseFailed(error.localizedDescription))
        }

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            return currentTier

        case .userCancelled:
            throw DateSnapError.subscription(.purchaseCancelled)

        case .pending:
            throw DateSnapError.subscription(.purchasePending)

        @unknown default:
            throw DateSnapError.subscription(.purchaseFailed("Unknown purchase outcome."))
        }
    }

    // MARK: - Restore Purchases
    public func restorePurchases() async throws -> SubscriptionTier {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
            return currentTier
        } catch {
            throw DateSnapError.subscription(.verificationFailed)
        }
    }

    // MARK: - Update Entitlements Status
    public func updateCustomerProductStatus() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                continue
            }
        }

        self.purchasedProductIDs = purchasedIDs

        if purchasedIDs.contains("com.datesnap.premium.monthly") || purchasedIDs.contains("com.datesnap.premium.annual") {
            self.currentTier = .premium
        } else if purchasedIDs.contains("com.datesnap.plus.monthly") || purchasedIDs.contains("com.datesnap.plus.annual") {
            self.currentTier = .plus
        } else {
            self.currentTier = .starter
        }
    }

    // MARK: - Verify Cryptographic JWS Signature
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw DateSnapError.subscription(.verificationFailed)
        case .verified(let safe):
            return safe
        }
    }
}
