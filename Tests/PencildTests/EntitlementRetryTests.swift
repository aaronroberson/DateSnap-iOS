import Foundation
import StoreKit
import Testing
@testable import Pencild

/// Subscription double whose refresh resolves to a scripted snapshot.
@MainActor
private final class ScriptedSubscriptionService: SubscriptionServiceProtocol {
    var entitlementSnapshot: EntitlementSnapshot
    private let afterRefresh: EntitlementSnapshot
    private(set) var refreshes: [EntitlementProvenance] = []

    init(initial: EntitlementSnapshot, afterRefresh: EntitlementSnapshot) {
        entitlementSnapshot = initial
        self.afterRefresh = afterRefresh
    }

    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }
    func refreshEntitlements(_ provenance: EntitlementProvenance) async {
        refreshes.append(provenance)
        entitlementSnapshot = afterRefresh
    }
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

@Suite("Entitlement retry at the paywall")
@MainActor
struct EntitlementRetryTests {
    @Test("While unresolved, gated features count as free")
    func unresolvedIsFree() {
        let appState = AppState()
        appState.bind(subscription: ScriptedSubscriptionService(
            initial: .checking(),
            afterRefresh: .verified(.premium, provenance: .gateRetry)
        ))
        #expect(appState.entitlementsUnresolved)
        #expect(!appState.isEntitled(to: .automaticScreenshotDetection))
        #expect(!appState.isEntitled(to: .documentImport))
    }

    @Test("A paywall re-requests an unresolved entitlement and is skipped when it resolves to a paid plan")
    func retryResolvesToPremium() async {
        let appState = AppState()
        let service = ScriptedSubscriptionService(
            initial: .checking(),
            afterRefresh: .verified(.premium, provenance: .gateRetry)
        )
        appState.bind(subscription: service)

        await appState.present(.paywall(opening: .premium))

        #expect(service.refreshes == [.gateRetry])
        #expect(appState.activeModal == nil)
        #expect(appState.subscriptionTier == .premium)
        #expect(!appState.entitlementsUnresolved)
        #expect(appState.isEntitled(to: .documentImport))
    }

    @Test("If the retry still doesn't resolve, the user stays free, sees the paywall, and the next gate retries again")
    func retryStillUnresolved() async {
        let appState = AppState()
        let service = ScriptedSubscriptionService(
            initial: .checking(),
            afterRefresh: EntitlementSnapshot(tier: .starter, state: .unavailable, evaluatedAt: Date(), provenance: .gateRetry)
        )
        appState.bind(subscription: service)

        await appState.present(.paywall(opening: .plus))
        #expect(appState.activeModal?.id == AppModalScreen.paywall(opening: .plus).id)
        #expect(appState.entitlementsUnresolved)

        await appState.present(.paywall(opening: .premium))
        #expect(service.refreshes == [.gateRetry, .gateRetry])
    }

    @Test("A verified free user is not re-checked before the paywall")
    func verifiedFreeSkipsRetry() async {
        let appState = AppState()
        let service = ScriptedSubscriptionService(
            initial: .verified(.starter, provenance: .launch),
            afterRefresh: .verified(.premium, provenance: .gateRetry)
        )
        appState.bind(subscription: service)

        await appState.present(.paywall(opening: .plus))

        #expect(service.refreshes.isEmpty)
        #expect(appState.activeModal?.id == AppModalScreen.paywall(opening: .plus).id)
    }

    @Test("A verified Premium member is never shown a paywall")
    func premiumNeverSeesPaywall() async {
        let appState = AppState()
        appState.bind(subscription: ScriptedSubscriptionService(
            initial: .verified(.premium, provenance: .launch),
            afterRefresh: .verified(.premium, provenance: .gateRetry)
        ))

        await appState.present(.paywall(opening: .plus))
        await appState.present(.paywall(opening: .premium))

        #expect(appState.activeModal == nil)
    }
}
