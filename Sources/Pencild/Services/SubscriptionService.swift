import Foundation
import OSLog
import StoreKit

// MARK: - Subscription Entitlement Tiers
public enum SubscriptionTier: String, CaseIterable, Identifiable, Sendable, Codable {
    case starter = "Starter" // Free: manual review, single scans
    case plus = "Plus"       // Screenshot & photo auto-detection
    case premium = "Premium" // Everything in Plus, PDF & Files import, duplicates, tailored alert plans

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .starter: return "Pencil’d Free"
        case .plus: return "Pencil’d Plus"
        case .premium: return "Pencil’d Premium"
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
    /// Seeded from the persisted `SubscriptionLease` (if any) so a paid subscriber keeps their
    /// features while StoreKit's `currentEntitlements` stream is unresolved (offline, cold launch).
    @Published public private(set) var entitlementSnapshot: EntitlementSnapshot = .checking()

    public var isSubscribed: Bool {
        currentTier != .starter
    }

    public static let productIdentifiers: Set<String> = SubscriptionCatalog.productIdentifiers
    /// How long a paywall waits for App Store prices before showing them as unavailable.
    static let productFetchTimeout: Duration = .seconds(8)

    private var updateListenerTask: Task<Void, Error>? = nil
    /// Completes purchases started from an App Store promoted-product surface.
    private var purchaseIntentTask: Task<Void, Never>? = nil
    /// Refreshes entitlements when a subscription's status changes (cancel, un-cancel, grace
    /// period, renewal) so the lease and banners stay current without a relaunch.
    private var statusListenerTask: Task<Void, Never>? = nil
    /// Keeps asking StoreKit for a live answer while the entitlement is unresolved or provisional.
    private var retryTask: Task<Void, Never>? = nil
    private let retryPolicy = EntitlementRetryPolicy.standard
    /// Only the app's real service retries in the background; test instances stay deterministic.
    private var runsBackgroundWork = false
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
        // Seed the snapshot from the last StoreKit-verified entitlement so a paid subscriber
        // keeps their features while `currentEntitlements` is unresolved (offline, cold launch).
        // StoreKit corrects this on the next successful refresh (see `resolveEntitlements`).
        if let lease = EntitlementCache.load(), lease.isActive() {
            entitlementSnapshot = .verified(lease.tier, at: lease.evaluatedAt, provenance: .cached)
            currentTier = lease.tier
        }
        runsBackgroundWork = observesTransactionUpdates

        if observesTransactionUpdates {
            updateListenerTask = listenForTransactions()
            purchaseIntentTask = listenForPurchaseIntents()
            statusListenerTask = listenForStatusChanges()
        }

        // Enqueue the launch refresh synchronously so it runs before any refresh requested later.
        // Products are no longer fetched at launch: they are lazy-loaded by `PurchaseViewModel`
        // when a paywall or Manage Plan appears, so a cold launch never stalls on the App Store.
        let launch = enqueueRefresh(.launch)
        Task { await launch.value }
        startBackgroundRetries()
    }

    deinit {
        updateListenerTask?.cancel()
        purchaseIntentTask?.cancel()
        statusListenerTask?.cancel()
        retryTask?.cancel()
    }

    // MARK: - Promoted purchases
    /// StoreKit delivers a PurchaseIntent when a user starts one of our products from the
    /// App Store. Completing it here is required before enabling promoted products in App Store
    /// Connect; the normal transaction listener then resolves the entitlement.
    private func listenForPurchaseIntents() -> Task<Void, Never> {
        Task { [weak self] in
            for await intent in PurchaseIntent.intents {
                guard !Task.isCancelled else { break }
                do {
                    _ = try await self?.purchase(product: intent.product)
                } catch {
                    Self.logger.error("Promoted purchase could not be completed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.setTransactionUpdateInFlight(true)
                do {
                    let transaction = try Self.checkVerified(result)
                    let record = Self.record(for: transaction)
                    await self?.applyVerified(record, provenance: .transactionUpdate)
                    await self?.refreshEntitlements(.transactionUpdate)
                    await transaction.finish()
                } catch {
                    Self.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
                await self?.setTransactionUpdateInFlight(false)
            }
        }
    }

    private func listenForStatusChanges() -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard !Task.isCancelled else { break }
                await self?.refreshEntitlements(.transactionUpdate)
            }
        }
    }

    // MARK: - Background retries
    /// While the answer is unresolved or provisional, ask StoreKit again with backoff until a live
    /// verified answer lands. Safe to call repeatedly; a single loop runs at a time.
    func startBackgroundRetries() {
        guard runsBackgroundWork, retryTask == nil, entitlementSnapshot.needsLiveVerification else { return }
        retryTask = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let delay = self?.retryPolicy.delay(afterFailures: failures) else { break }
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled, let self, self.entitlementSnapshot.needsLiveVerification else { break }
                await self.refreshEntitlements(.gateRetry)
                failures += 1
            }
            self?.retryTask = nil
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
            // Bounded so an offline paywall shows "Price unavailable" instead of loading forever.
            let identifiers = Self.productIdentifiers
            let products = try await withDeadline(Self.productFetchTimeout) {
                try await Product.products(for: identifiers)
            }
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
            // Grant the verified purchase right away; the stream can lag or time out (offline),
            // and a paying subscriber must never wait on it.
            applyVerified(Self.record(for: transaction), provenance: .purchase)
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

    /// One verified or unverified entitlement transaction plus the subscription group it belongs to.
    private struct EntitlementEntry: Sendable {
        let record: SubscriptionEntitlementRecord
        let groupID: String?
    }

    private func resolveEntitlements(_ provenance: EntitlementProvenance, generation: Int) async {
        // A gated attempt is waiting on this answer, so give up sooner than a background refresh.
        let interactive = provenance == .gateRetry
        let entitlementTimeout: Duration = interactive ? .milliseconds(1500) : .seconds(3)
        let statusTimeout: Duration = interactive ? .seconds(1) : .seconds(2)

        // Bound the `currentEntitlements` stream with a deadline. Offline (or a stalled StoreKit
        // sandbox), the stream can hang; the offline lease keeps a paid subscriber's features on.
        // `withDeadline` returns on time even if the stream ignores cancellation.
        let entries: [EntitlementEntry]
        do {
            entries = try await withDeadline(entitlementTimeout) {
                var collected: [EntitlementEntry] = []
                for await result in Transaction.currentEntitlements {
                    switch result {
                    case .verified(let transaction):
                        collected.append(EntitlementEntry(
                            record: Self.record(for: transaction),
                            groupID: transaction.subscriptionGroupID
                        ))
                    case .unverified(let transaction, _):
                        // Keep the unverifiable payload so the resolver fails the snapshot closed
                        // (mirrors the audited "failed verification fails the snapshot closed" contract).
                        Self.logger.warning("Entitlement verification failed for \(transaction.productID); resolver will fail the snapshot closed")
                        collected.append(EntitlementEntry(
                            record: SubscriptionEntitlementRecord(
                                productID: transaction.productID,
                                expirationDate: transaction.expirationDate,
                                revocationDate: transaction.revocationDate,
                                verification: .unverified
                            ),
                            groupID: nil
                        ))
                    }
                }
                return collected
            }
        } catch {
            Self.logger.warning("Entitlement resolution did not finish (\(error.localizedDescription)); keeping the offline lease (provenance=\(provenance.rawValue))")
            handleResolutionFailure(provenance: provenance, generation: generation)
            return
        }

        // Renewal status (cancelled, in grace, renewing) is best effort: when it can't be read the
        // outlook is simply unknown, which never removes access by itself.
        let facts = await Self.fetchRenewalFacts(groupIDs: Set(entries.compactMap(\.groupID)), timeout: statusTimeout)
        let records = entries.map { entry in
            SubscriptionEntitlementRecord(
                productID: entry.record.productID,
                expirationDate: entry.record.expirationDate,
                revocationDate: entry.record.revocationDate,
                verification: entry.record.verification,
                renewal: facts[entry.record.productID]
            )
        }

        guard generation == appliedGeneration else { return }
        publish(SubscriptionEntitlementResolver.resolve(records, provenance: provenance))
    }

    private func handleResolutionFailure(provenance: EntitlementProvenance, generation: Int) {
        guard generation == appliedGeneration else { return }
        defer { startBackgroundRetries() }
        // Keep a verified paid snapshot only while its lease still vouches for it; past that, or
        // with no lease, fail to `.unavailable` (the UI asks the user to retry, it doesn't paywall).
        let leaseVouches = EntitlementCache.load()?.isActive() ?? false
        let keepsPaidAccess = entitlementSnapshot.state == .verified
            && (entitlementSnapshot.tier == .starter || leaseVouches)
        if !keepsPaidAccess {
            publish(SubscriptionEntitlementResolution(
                snapshot: EntitlementSnapshot(tier: .starter, state: .unavailable, provenance: provenance),
                activeProductIDs: [],
                verificationFailureCount: 0
            ))
        }
    }

    // MARK: - Renewal status
    nonisolated static func fetchRenewalFacts(groupIDs: Set<String>, timeout: Duration) async -> [String: RenewalFacts] {
        guard !groupIDs.isEmpty else { return [:] }
        let facts = try? await withDeadline(timeout) {
            var facts: [String: RenewalFacts] = [:]
            for groupID in groupIDs {
                guard let statuses = try? await Product.SubscriptionInfo.status(for: groupID) else { continue }
                for status in statuses {
                    if let (productID, fact) = Self.renewalFacts(from: status) { facts[productID] = fact }
                }
            }
            return facts
        }
        return facts ?? [:]
    }

    nonisolated static func renewalFacts(from status: Product.SubscriptionInfo.Status) -> (String, RenewalFacts)? {
        guard case .verified(let transaction) = status.transaction,
              case .verified(let renewal) = status.renewalInfo else { return nil }
        let state: RenewalFacts.State
        switch status.state {
        case .subscribed: state = .subscribed
        case .inGracePeriod: state = .inGracePeriod
        case .inBillingRetryPeriod: state = .inBillingRetry
        case .revoked: state = .revoked
        default: state = .expired
        }
        return (
            transaction.productID,
            RenewalFacts(
                state: state,
                willAutoRenew: renewal.willAutoRenew,
                gracePeriodExpirationDate: renewal.gracePeriodExpirationDate
            )
        )
    }

    /// Applies a resolver output to the published state. Internal so tests can drive the
    /// resolution path hermetically, without StoreKit.
    func apply(_ resolution: SubscriptionEntitlementResolution) {
        appliedGeneration += 1
        publish(resolution)
    }

    private func publish(_ resolution: SubscriptionEntitlementResolution) {
        // Persist the lease from every verified answer so the next launch (offline or not) can seed
        // from it, and so banners derived from it are current when the snapshot change lands. A
        // verified answer with no paid plan clears it, so a lapsed subscriber can't be restored
        // from a stale lease. Unverified/unavailable answers leave it untouched.
        if resolution.snapshot.state == .verified {
            if let lease = resolution.lease {
                EntitlementCache.save(lease)
            } else {
                EntitlementCache.clear()
            }
        }
        purchasedProductIDs = resolution.activeProductIDs
        currentTier = resolution.snapshot.effectiveTier
        entitlementSnapshot = resolution.snapshot
        startBackgroundRetries()
    }

    /// Grants a StoreKit-verified transaction immediately, so a new subscriber isn't locked out
    /// while the entitlement stream is slow or offline. It only ever raises access (free to a
    /// paid tier, or to a higher tier): a same-tier update carries no renewal details and must not
    /// overwrite a richer lease. The full refresh that follows reconciles everything else.
    func applyVerified(_ record: SubscriptionEntitlementRecord, provenance: EntitlementProvenance) {
        let resolution = SubscriptionEntitlementResolver.resolve([record], provenance: provenance)
        guard resolution.snapshot.state == .verified,
              resolution.snapshot.tier.rank > entitlementSnapshot.effectiveTier.rank else { return }
        apply(resolution)
    }

    nonisolated static func record(for transaction: StoreKit.Transaction) -> SubscriptionEntitlementRecord {
        SubscriptionEntitlementRecord(
            productID: transaction.productID,
            expirationDate: transaction.expirationDate,
            revocationDate: transaction.revocationDate,
            verification: .verified
        )
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
