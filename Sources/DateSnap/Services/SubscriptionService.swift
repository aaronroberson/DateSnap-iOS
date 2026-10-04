import Foundation
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
/// Refines `EntitlementProviding`: every subscription service that backs `ServiceContainer`
/// carries the entitlement snapshot and the provenance-stamped refresh contract, so callers
/// (e.g. scene-activation refresh) need no type-casting.
@MainActor
public protocol SubscriptionServiceProtocol: EntitlementProviding {
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

    @Published public private(set) var currentTier: SubscriptionTier = .starter
    @Published public private(set) var availableProducts: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading: Bool = false
    /// Latest resolved entitlement projection, stamped with the provenance that produced it.
    /// Starts `.checking` and becomes `.verified`/`.unverified` after the first resolution pass.
    @Published public private(set) var entitlementSnapshot: EntitlementSnapshot = .checking()

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
            await refreshEntitlements(.launch)
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
                    await self?.refreshEntitlements(.transactionUpdate)
                    await transaction.finish()
                } catch {
                    // Transaction verification failed
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
            await refreshEntitlements(.purchase)
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
            await refreshEntitlements(.restore)
            return currentTier
        } catch {
            throw DateSnapError.subscription(.verificationFailed)
        }
    }

    // MARK: - Entitlement Refresh
    /// Transaction-driven refresh (protocol entry point retained for compatibility).
    public func updateCustomerProductStatus() async {
        await refreshEntitlements(.transactionUpdate)
    }

    /// Re-resolves entitlements from the current StoreKit transaction stream through the
    /// canonical `SubscriptionEntitlementResolver` and stamps the snapshot with the given
    /// provenance (launch, purchase, restore, transaction update, or scene activation).
    /// Silent by design: never triggers sign-in UI and never toggles `isLoading` — use
    /// `restorePurchases()` for the interactive path.
    public func refreshEntitlements(_ provenance: EntitlementProvenance) async {
        var records: [SubscriptionEntitlementRecord] = []

        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                records.append(SubscriptionEntitlementRecord(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    verification: .verified
                ))
            case .unverified(let transaction, _):
                // Keep the unverifiable payload so the resolver fails the snapshot closed
                // (mirrors the audited "failed verification fails the snapshot closed" contract).
                records.append(SubscriptionEntitlementRecord(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    verification: .unverified
                ))
            }
        }

        apply(SubscriptionEntitlementResolver.resolve(records, provenance: provenance))
    }

    /// Applies a resolver output to the published state. Internal so tests can drive the
    /// resolution path hermetically, without StoreKit.
    func apply(_ resolution: SubscriptionEntitlementResolution) {
        purchasedProductIDs = resolution.activeProductIDs
        currentTier = resolution.snapshot.tier
        entitlementSnapshot = resolution.snapshot
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
