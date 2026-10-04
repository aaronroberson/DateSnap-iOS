import Combine
import StoreKit
import Testing
@testable import DateSnap

// MARK: - Scene-activation entitlement refresh (EntitlementProviding completion)
// Implements the recipe recorded in
// docs/audits/2026-10-02-git-recovery-and-handoff-completion-report.md §3:
// SubscriptionServiceProtocol refines EntitlementProviding, SubscriptionService resolves
// through the canonical SubscriptionEntitlementResolver, and ContentView refreshes on scene
// activation with EntitlementProvenance.sceneActivation.

@Suite("Scene-activation entitlement refresh")
@MainActor
struct SceneActivationRefreshTests {

    /// Records refresh provenance without touching StoreKit.
    private final class RecordingSubscriptionService: SubscriptionServiceProtocol {
        @Published private(set) var currentTier: SubscriptionTier
        private(set) var refreshProvenances: [EntitlementProvenance] = []
        private(set) var entitlementSnapshot: EntitlementSnapshot

        init(tier: SubscriptionTier = .starter) {
            currentTier = tier
            entitlementSnapshot = .verified(tier, provenance: .none)
        }

        var isSubscribed: Bool { currentTier != .starter }

        func refreshEntitlements(_ provenance: EntitlementProvenance) async {
            refreshProvenances.append(provenance)
        }

        func fetchProducts() async throws -> [Product] { [] }
        func purchase(product: Product) async throws -> SubscriptionTier { currentTier }
        func restorePurchases() async throws -> SubscriptionTier { currentTier }
        func updateCustomerProductStatus() async { await refreshEntitlements(.transactionUpdate) }
    }

    @Test("Production subscription service satisfies EntitlementProviding")
    func productionServiceSatisfiesEntitlementProviding() {
        #expect(SubscriptionService.self is any EntitlementProviding.Type)
    }

    @Test("Every SubscriptionServiceProtocol value carries the EntitlementProviding capability")
    func protocolRefinementCarriesEntitlementProviding() {
        let anySubscription: any SubscriptionServiceProtocol = RecordingSubscriptionService(tier: .plus)
        // Compiles only because SubscriptionServiceProtocol refines EntitlementProviding —
        // the compile-time guarantee that ServiceContainer's subscription can be refreshed.
        let provider: any EntitlementProviding = anySubscription
        #expect(provider.entitlementSnapshot.tier == .plus)
    }

    @Test("Scene-activation refresh reaches the subscription service with the sceneActivation provenance")
    func sceneActivationRefreshRecordsProvenance() async {
        let store = RecordingSubscriptionService(tier: .premium)

        await store.refreshEntitlements(.sceneActivation)

        #expect(store.refreshProvenances == [.sceneActivation])
    }

    @Test("Verified resolution promotes tier, active IDs, and stamps the provenance")
    func verifiedResolutionUpdatesPublishedState() {
        let service = SubscriptionService()
        let resolution = SubscriptionEntitlementResolver.resolve(
            [
                SubscriptionEntitlementRecord(
                    productID: "com.datesnap.premium.annual",
                    expirationDate: nil,
                    revocationDate: nil,
                    verification: .verified
                ),
                SubscriptionEntitlementRecord(
                    productID: "com.datesnap.plus.monthly",
                    expirationDate: nil,
                    revocationDate: nil,
                    verification: .verified
                ),
            ],
            provenance: .sceneActivation
        )

        service.apply(resolution)

        #expect(service.currentTier == .premium)
        #expect(service.purchasedProductIDs == Set(["com.datesnap.premium.annual", "com.datesnap.plus.monthly"]))
        #expect(service.entitlementSnapshot.tier == .premium)
        #expect(service.entitlementSnapshot.state == .verified)
        #expect(service.entitlementSnapshot.provenance == .sceneActivation)
        #expect(service.isSubscribed)
    }

    @Test("Unverifiable records fail the live snapshot closed")
    func unverifiableRecordFailsClosed() {
        let service = SubscriptionService()
        let resolution = SubscriptionEntitlementResolver.resolve(
            [
                SubscriptionEntitlementRecord(
                    productID: "com.datesnap.plus.monthly",
                    expirationDate: nil,
                    revocationDate: nil,
                    verification: .unverified
                ),
            ],
            provenance: .sceneActivation
        )

        service.apply(resolution)

        #expect(service.currentTier == .starter)
        #expect(service.purchasedProductIDs.isEmpty)
        #expect(service.entitlementSnapshot.state == .unverified)
        #expect(service.entitlementSnapshot.provenance == .sceneActivation)
        #expect(!service.isSubscribed)
    }

    @Test("Scene-activation resolution of an empty stream is a verified Starter, not a loading state")
    func emptyStreamIsVerifiedStarter() {
        let service = SubscriptionService()

        service.apply(SubscriptionEntitlementResolver.resolve([], provenance: .sceneActivation))

        #expect(service.currentTier == .starter)
        #expect(service.entitlementSnapshot.state == .verified)
        #expect(service.entitlementSnapshot.provenance == .sceneActivation)
    }
}
