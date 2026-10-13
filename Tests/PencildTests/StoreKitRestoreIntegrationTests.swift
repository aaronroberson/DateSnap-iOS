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

    /// Out-of-band purchases are delivered to every live `Transaction.updates` listener — the
    /// test host's `SubscriptionService.shared` as well as the instance under test — and each
    /// finishes the transaction asynchronously. Clearing the session before those finishes land
    /// makes StoreKit log "Error finishing transaction", so wait for them to drain first.
    private func drainAndClear(_ session: SKTestSession) async throws {
        for _ in 0..<100 {
            var pending = false
            for await _ in Transaction.unfinished { pending = true; break }
            if !pending { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        session.clearTransactions()
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

        let service = SubscriptionService()
        let tier = try await service.restorePurchases()

        #expect(tier == .starter)
        #expect(service.purchasedProductIDs.isEmpty)
        try await drainAndClear(session)
    }

    @Test("Restore after an out-of-band purchase unlocks the purchased tier", arguments: [
        ("com.pencild.plus.monthly", SubscriptionTier.plus),
        ("com.pencild.premium.annual", SubscriptionTier.premium),
    ])
    func positiveRestoreUnlocksPurchasedTier(productID: String, expected: SubscriptionTier) async throws {
        let session = try makeSession()

        // Purchase out-of-band (as on another device) so this service instance has never
        // observed the transaction; only restore can surface it.
        _ = try await session.buyProduct(identifier: productID)

        let service = SubscriptionService()
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
        try session.expireSubscription(productIdentifier: transaction.productID)

        let service = SubscriptionService()
        let tier = try await service.restorePurchases()

        #expect(tier == .starter)
        #expect(!service.isSubscribed)
        try await drainAndClear(session)
    }
}
