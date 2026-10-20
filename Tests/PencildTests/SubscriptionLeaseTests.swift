import Foundation
import Testing
@testable import Pencild

@Suite("Subscription lease and resolver")
struct SubscriptionLeaseTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private let day: TimeInterval = 86_400

    private func lease(_ outlook: RenewalOutlook, expires: Date?, evaluated: Date? = nil) -> SubscriptionLease {
        SubscriptionLease(tier: .plus, outlook: outlook, expirationDate: expires, evaluatedAt: evaluated ?? now.addingTimeInterval(-60))
    }

    // MARK: Lease

    @Test("cancelled plan ends exactly at expiry, with no tolerance")
    func endsAtExpiry() {
        let expiry = now.addingTimeInterval(2 * day)
        #expect(lease(.endsAtExpiry, expires: expiry).isActive(at: expiry.addingTimeInterval(-1)))
        #expect(!lease(.endsAtExpiry, expires: expiry).isActive(at: expiry))
    }

    @Test("renewing and unknown plans get 3 days past expiry")
    func renewingTolerance() {
        let expiry = now.addingTimeInterval(-day) // expired yesterday
        for outlook in [RenewalOutlook.renewing, .unknown] {
            #expect(lease(outlook, expires: expiry).isActive(at: now))
            #expect(!lease(outlook, expires: expiry).isActive(at: expiry.addingTimeInterval(3 * day)))
        }
    }

    @Test("grace period keeps access until the grace end")
    func graceUntil() {
        let expiry = now.addingTimeInterval(-day)
        let graceEnd = now.addingTimeInterval(5 * day)
        let graced = lease(.inGrace(until: graceEnd), expires: expiry)
        #expect(graced.isActive(at: now))
        #expect(!graced.isActive(at: graceEnd))
    }

    @Test("no expiry known falls back to 7 days from the last good check")
    func unknownWithoutExpiry() {
        let evaluated = now.addingTimeInterval(-6 * day)
        #expect(lease(.unknown, expires: nil, evaluated: evaluated).isActive(at: now))
        #expect(!lease(.unknown, expires: nil, evaluated: now.addingTimeInterval(-8 * day)).isActive(at: now))
    }

    @Test("lifetime never expires; a clock moved back is distrusted")
    func lifetimeAndClock() {
        #expect(lease(.lifetime, expires: nil).isActive(at: now.addingTimeInterval(3650 * day)))
        #expect(!lease(.lifetime, expires: nil, evaluated: now.addingTimeInterval(3600)).isActive(at: now))
    }

    // MARK: Resolver

    private func record(_ id: String, expires: Date?, revoked: Date? = nil, renewal: RenewalFacts? = nil,
                        verification: EntitlementRecordVerification = .verified) -> SubscriptionEntitlementRecord {
        SubscriptionEntitlementRecord(productID: id, expirationDate: expires, revocationDate: revoked,
                                      verification: verification, renewal: renewal)
    }

    @Test("an expired transaction in billing grace stays entitled")
    func graceKeepsAccess() {
        let result = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.monthly", expires: now.addingTimeInterval(-day),
                   renewal: RenewalFacts(state: .inGracePeriod, willAutoRenew: true,
                                         gracePeriodExpirationDate: now.addingTimeInterval(4 * day)))
        ], now: now)
        #expect(result.snapshot.effectiveTier == .plus)
        #expect(result.lease?.outlook == .inGrace(until: now.addingTimeInterval(4 * day)))
    }

    @Test("billing retry without grace, and an expired transaction, are not entitled")
    func retryWithoutGraceDenied() {
        let retry = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.monthly", expires: now.addingTimeInterval(-day),
                   renewal: RenewalFacts(state: .inBillingRetry, willAutoRenew: true))
        ], now: now)
        #expect(retry.snapshot.effectiveTier == .starter)
        #expect(retry.lease == nil)
    }

    @Test("cancelled-but-paid-up reads as ends-at-expiry; refunds are revoked")
    func cancelledAndRefunded() {
        let expiry = now.addingTimeInterval(10 * day)
        let cancelled = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.annual", expires: expiry, renewal: RenewalFacts(state: .subscribed, willAutoRenew: false))
        ], now: now)
        #expect(cancelled.lease?.outlook == .endsAtExpiry)
        let refunded = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.annual", expires: expiry, revoked: now.addingTimeInterval(-60))
        ], now: now)
        #expect(refunded.snapshot.effectiveTier == .starter)
    }

    @Test("missing renewal facts mean unknown, and the highest tier wins")
    func unknownAndHighestTier() {
        let expiry = now.addingTimeInterval(10 * day)
        let result = SubscriptionEntitlementResolver.resolve([
            record("com.pencild.plus.annual", expires: expiry),
            record("com.pencild.premium.monthly", expires: expiry)
        ], now: now)
        #expect(result.snapshot.effectiveTier == .premium)
        #expect(result.lease?.tier == .premium)
        #expect(result.lease?.outlook == .unknown)
    }

    @Test("lifetime purchase resolves to a lifetime lease")
    func lifetime() {
        let result = SubscriptionEntitlementResolver.resolve([record("com.pencild.plus.lifetime", expires: nil)], now: now)
        #expect(result.lease?.outlook == .lifetime)
    }

    // MARK: Retry policy

    @Test("retry delays back off, then hold steady")
    func retrySchedule() {
        let policy = EntitlementRetryPolicy.standard
        #expect(policy.delay(afterFailures: 0) == .seconds(2))
        #expect(policy.delay(afterFailures: 3) == .seconds(60))
        #expect(policy.delay(afterFailures: 4) == .seconds(300))
        #expect(policy.delay(afterFailures: 99) == .seconds(300))
    }

    @Test("a lease-backed snapshot is provisional and still needs live verification")
    func provisionalSnapshot() {
        let cached = EntitlementSnapshot.verified(.plus, provenance: .cached)
        #expect(cached.isProvisional && cached.needsLiveVerification)
        let live = EntitlementSnapshot.verified(.plus, provenance: .storeKit)
        #expect(!live.isProvisional && !live.needsLiveVerification)
    }
}
