import Foundation
import Testing
@testable import Pencild

@Suite("Lifetime introductory offer")
struct LifetimeOfferTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test("The offer is shown through April 13, 2027 and hidden from April 14")
    func promoWindow() {
        #expect(LifetimeIntroOffer.isAvailable(at: date(2026, 10, 13), calendar: calendar))
        #expect(LifetimeIntroOffer.isAvailable(at: date(2027, 4, 13, hour: 23), calendar: calendar))
        #expect(!LifetimeIntroOffer.isAvailable(at: date(2027, 4, 14, hour: 0), calendar: calendar))
    }

    @Test("Each paid tier has monthly, annual, and lifetime products")
    @MainActor
    func catalogCoversLifetime() {
        for tier in [SubscriptionTier.plus, .premium] {
            for period in BillingPeriod.allCases {
                #expect(SubscriptionCatalog.product(tier: tier, period: period) != nil)
            }
        }
        #expect(SubscriptionCatalog.product(tier: .plus, period: .lifetime)?.rawValue == "com.pencild.plus.lifetime")
        #expect(SubscriptionService.productIdentifiers == SubscriptionCatalog.productIdentifiers)
    }

    @Test("A verified lifetime purchase never expires and grants its tier")
    func lifetimeResolvesWithoutExpiration() {
        let farFuture = date(2040, 1, 1)
        let resolution = SubscriptionEntitlementResolver.resolve(
            [SubscriptionEntitlementRecord(
                productID: "com.pencild.premium.lifetime",
                expirationDate: nil,
                revocationDate: nil,
                verification: .verified
            )],
            now: farFuture
        )
        #expect(resolution.snapshot.tier == .premium)
        #expect(resolution.activeProductIDs == ["com.pencild.premium.lifetime"])
    }

    @Test("A refunded lifetime purchase grants nothing")
    func revokedLifetimeGrantsNothing() {
        let resolution = SubscriptionEntitlementResolver.resolve([
            SubscriptionEntitlementRecord(
                productID: "com.pencild.plus.lifetime",
                expirationDate: nil,
                revocationDate: date(2026, 11, 1),
                verification: .verified
            )
        ])
        #expect(resolution.snapshot.tier == .starter)
    }
}
