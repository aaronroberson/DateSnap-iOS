import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Pencild

/// Drives the real `SubscriptionService` against the repository's local StoreKit catalog
/// through `SKTestSession`, so the positive restore path is exercised without depending on
/// the scheme's launch-time catalog synchronization. The catalog is loaded from the
/// checkout (simulator test runs share the host file system); no products or prices are
/// fabricated in production code.
@MainActor
@Suite("StoreKit local catalog restore integration", .serialized)
struct StoreKitRestoreIntegrationTests {
    private static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // PencildTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repository root
        .appendingPathComponent("Pencild.storekit")

    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(contentsOf: Self.catalogURL)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    /// Out-of-band purchases are delivered to the `Transaction.updates` listener, which finishes
    /// them asynchronously. Clearing the session before that finish lands makes StoreKit log
    /// "Error finishing transaction", so wait for it to drain first. Tests drive the app's single
    /// `SubscriptionService.shared` so there is exactly one listener finishing each transaction.
    private func drainAndClear(_ session: SKTestSession) async throws {
        try await drainUnfinished()
        session.clearTransactions()
    }

    /// Waits until no transaction is unfinished and the app listener is idle, observed on
    /// several consecutive polls so an update that is just being delivered is not missed.
    private func drainUnfinished() async throws {
        var quietPolls = 0
        for _ in 0..<200 where quietPolls < 3 {
            var pending = SubscriptionService.shared.isProcessingTransactionUpdate
            if !pending {
                for await _ in Transaction.unfinished { pending = true; break }
            }
            quietPolls = pending ? 0 : quietPolls + 1
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @Test("Local catalog exposes every subscription product identifier")
    func catalogLoadsAllProducts() async throws {
        let session = try makeSession()

        let products = try await Product.products(for: SubscriptionService.productIdentifiers)
        #expect(Set(products.map(\.id)) == SubscriptionService.productIdentifiers)
        #expect(products.allSatisfy { $0.price > 0 })
        try await drainAndClear(session)
    }

    @Test("Restore with no purchased transaction resolves to the free tier")
    func emptyRestoreResolvesStarter() async throws {
        let session = try makeSession()

        let service = SubscriptionService.shared
        let tier = try await service.restorePurchases()

        #expect(tier == .starter)
        #expect(service.purchasedProductIDs.isEmpty)
        try await drainAndClear(session)
    }

    @Test("Restore after an out-of-band purchase unlocks the purchased tier", .serialized, arguments: [
        ("com.pencild.plus.monthly", SubscriptionTier.plus),
        ("com.pencild.premium.annual", SubscriptionTier.premium),
        ("com.pencild.plus.lifetime", SubscriptionTier.plus),
        ("com.pencild.premium.lifetime", SubscriptionTier.premium),
    ])
    func positiveRestoreUnlocksPurchasedTier(productID: String, expected: SubscriptionTier) async throws {
        let session = try makeSession()

        // Purchase out-of-band, as if made on another device.
        _ = try await session.buyProduct(identifier: productID)

        // The listener also receives the unfinished purchase and starts its own refresh;
        // restore must still report the purchased tier rather than a stale read.
        let service = SubscriptionService.shared
        let tier = try await service.restorePurchases()

        #expect(tier == expected)
        #expect(service.currentTier == expected)
        #expect(service.purchasedProductIDs.contains(productID))
        #expect(service.isSubscribed)
        try await drainAndClear(session)
    }

    @Test("Expired subscription does not restore an entitlement")
    func expiredSubscriptionRestoresStarter() async throws {
        let session = try makeSession()

        let transaction = try await session.buyProduct(identifier: "com.pencild.plus.monthly")
        // Let the listener finish the purchase before expiring it, so its finish() does not
        // target a transaction the test session has already replaced.
        try await drainUnfinished()
        try session.expireSubscription(productIdentifier: transaction.productID)

        let service = SubscriptionService.shared
        let tier = try await service.restorePurchases()

        #expect(tier == .starter)
        #expect(!service.isSubscribed)
        try await drainAndClear(session)
    }
}
