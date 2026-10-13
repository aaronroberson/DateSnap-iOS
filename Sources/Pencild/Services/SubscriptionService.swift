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
    /// Entitlement refreshes run one at a time in request order, so a later refresh always
    /// reads StoreKit after an earlier one finished and can never be overwritten by it.
    private var refreshQueue: Task<Void, Never>? = nil
    /// True while the listener is refreshing and finishing a delivered transaction. Lets
    /// StoreKit integration tests wait for `finish()` before clearing their test session.
    private(set) var isProcessingTransactionUpdate = false
    /// Bumped only by `apply(_:)`. A refresh requested before a direct apply does not publish.
    private var appliedGeneration = 0

    public convenience init() {
        self.init(observesTransactionUpdates: true)
    }

    /// Tests that only exercise entitlement resolution pass `false`, so they do not add a
    /// second `Transaction.updates` listener that races the app's listener to finish purchases.
    init(observesTransactionUpdates: Bool) {
        if observesTransactionUpdates {
            updateListenerTask = listenForTransactions()
        }

        // Enqueue the launch refresh synchronously so it runs before any refresh requested later.
        let launch = enqueueRefresh(.launch)
        Task {
            await launch.value
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
                await self?.setTransactionUpdateInFlight(true)
                do {
                    let transaction = try Self.checkVerified(result)
                    await self?.refreshEntitlements(.transactionUpdate)
                    await transaction.finish()
                } catch {
                    Self.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
                await self?.setTransactionUpdateInFlight(false)
            }
        }
    }

    private func setTransactionUpdateInFlight(_ inFlight: Bool) {
        isProcessingTransactionUpdate = inFlight
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
        await enqueueRefresh(provenance).value
    }

    private func enqueueRefresh(_ provenance: EntitlementProvenance) -> Task<Void, Never> {
        let previous = refreshQueue
        let generation = appliedGeneration
        let refresh = Task {
            await previous?.value
            await resolveEntitlements(provenance, generation: generation)
        }
        refreshQueue = refresh
        return refresh
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

        guard generation == appliedGeneration else { return }
        publish(SubscriptionEntitlementResolver.resolve(records, provenance: provenance))
    }

    /// Applies a resolver output to the published state. Internal so tests can drive the
    /// resolution path hermetically, without StoreKit.
    func apply(_ resolution: SubscriptionEntitlementResolution) {
        appliedGeneration += 1
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
