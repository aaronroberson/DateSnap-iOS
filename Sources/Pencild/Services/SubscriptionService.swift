import Foundation
import OSLog
import StoreKit

// MARK: - Subscription Entitlement Tiers
public enum SubscriptionTier: String, CaseIterable, Identifiable, Sendable {
    case starter = "Starter" // Free: manual review, single scans
    case plus = "Plus"       // Screenshot & photo auto-detection
    case premium = "Premium" // Full automation, files/PDF import, unlimited history

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .starter: return "Pencil'd Free"
        case .plus: return "Pencil'd Plus"
        case .premium: return "Pencil'd Premium"
        }
    }

    public var badgeText: String {
        switch self {
        case .starter: return "FREE"
        case .plus: return "PLUS"
        case .premium: return "PREMIUM"
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

    nonisolated private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.pencild.app", category: "SubscriptionService")

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
        "com.pencild.plus.monthly",
        "com.pencild.plus.annual",
        "com.pencild.premium.monthly",
        "com.pencild.premium.annual"
    ]

    private var updateListenerTask: Task<Void, Error>? = nil
    /// Reserved when a refresh is requested or a resolution is applied directly. A refresh only
    /// publishes if no newer refresh/apply was requested while it was reading StoreKit, so a
    /// slow launch read cannot overwrite a later restore or transaction update.
    private var entitlementGeneration = 0

    public init() {
        updateListenerTask = listenForTransactions()

        // Reserve the launch generation now: the Task starts later, after any refresh the
        // caller requests, and must not outrank it.
        let launchGeneration = reserveEntitlementGeneration()
        Task {
            await resolveEntitlements(.launch, generation: launchGeneration)
            _ = try? await fetchProducts()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(result)
                    await self?.refreshEntitlements(.transactionUpdate)
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
            throw PencildError.subscription(.productNotFound(error.localizedDescription))
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
            throw PencildError.subscription(.purchaseFailed(error.localizedDescription))
        }

        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await refreshEntitlements(.purchase)
            await transaction.finish()
            return currentTier

        case .userCancelled:
            throw PencildError.subscription(.purchaseCancelled)

        case .pending:
            throw PencildError.subscription(.purchasePending)

        @unknown default:
            throw PencildError.subscription(.purchaseFailed("Unknown purchase outcome."))
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
        } catch StoreKitError.userCancelled {
            throw PencildError.subscription(.purchaseCancelled)
        } catch {
            Self.logger.error("Restore purchases failed: \(error.localizedDescription)")
            throw PencildError.subscription(.restoreFailed)
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
        await resolveEntitlements(provenance, generation: reserveEntitlementGeneration())
    }

    private func reserveEntitlementGeneration() -> Int {
        entitlementGeneration += 1
        return entitlementGeneration
    }

    private func resolveEntitlements(_ provenance: EntitlementProvenance, generation: Int) async {
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
                Self.logger.warning("Entitlement verification failed for \(transaction.productID); resolver will fail the snapshot closed")
                records.append(SubscriptionEntitlementRecord(
                    productID: transaction.productID,
                    expirationDate: transaction.expirationDate,
                    revocationDate: transaction.revocationDate,
                    verification: .unverified
                ))
            }
        }

        guard generation == entitlementGeneration else { return }
        publish(SubscriptionEntitlementResolver.resolve(records, provenance: provenance))
    }

    /// Applies a resolver output to the published state. Internal so tests can drive the
    /// resolution path hermetically, without StoreKit.
    func apply(_ resolution: SubscriptionEntitlementResolution) {
        _ = reserveEntitlementGeneration()
        publish(resolution)
    }

    private func publish(_ resolution: SubscriptionEntitlementResolution) {
        purchasedProductIDs = resolution.activeProductIDs
        currentTier = resolution.snapshot.tier
        entitlementSnapshot = resolution.snapshot
    }

    // MARK: - Verify Cryptographic JWS Signature
    nonisolated internal static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PencildError.subscription(.verificationFailed)
        case .verified(let safe):
            return safe
        }
    }
}
