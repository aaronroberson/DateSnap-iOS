import Foundation
import Testing
@testable import Pencild

@Suite("Subscription notices")
struct SubscriptionNoticeTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private let day: TimeInterval = 86_400

    private func lease(_ outlook: RenewalOutlook, expires: Date?) -> SubscriptionLease {
        SubscriptionLease(tier: .plus, outlook: outlook, expirationDate: expires, evaluatedAt: now.addingTimeInterval(-60))
    }

    @Test("a cancelled plan ending within a week shows an ends-soon notice")
    func endsSoon() {
        let end = now.addingTimeInterval(3 * day)
        #expect(SubscriptionNotice.derive(from: lease(.endsAtExpiry, expires: end), now: now) == .endsSoon(tier: .plus, on: end))
    }

    @Test("a cancelled plan with more than a week left shows nothing yet")
    func endsLater() {
        #expect(SubscriptionNotice.derive(from: lease(.endsAtExpiry, expires: now.addingTimeInterval(20 * day)), now: now) == .none)
    }

    @Test("grace period shows a payment notice")
    func grace() {
        let graceEnd = now.addingTimeInterval(5 * day)
        let notice = SubscriptionNotice.derive(from: lease(.inGrace(until: graceEnd), expires: now.addingTimeInterval(-day)), now: now)
        #expect(notice == .paymentIssue(tier: .plus, until: graceEnd))
    }

    @Test("healthy, unknown, lifetime, or missing leases show nothing")
    func healthy() {
        for outlook in [RenewalOutlook.renewing, .unknown, .lifetime] {
            #expect(SubscriptionNotice.derive(from: lease(outlook, expires: now.addingTimeInterval(2 * day)), now: now) == .none)
        }
        #expect(SubscriptionNotice.derive(from: nil, now: now) == .none)
    }
}
