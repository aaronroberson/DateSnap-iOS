import Foundation

/// What the member should be told about their plan, derived from the offline lease.
enum SubscriptionNotice: Equatable {
    case none
    /// Cancelled but still paid up: access ends on the date.
    case endsSoon(tier: SubscriptionTier, on: Date)
    /// Renewal payment failed; Apple's grace period keeps access until the date.
    case paymentIssue(tier: SubscriptionTier, until: Date)

    /// How far ahead of the end date the "ends soon" notice appears.
    static let endsSoonWindow: TimeInterval = 7 * 24 * 60 * 60

    static func derive(from lease: SubscriptionLease?, now: Date = Date()) -> SubscriptionNotice {
        guard let lease, lease.isActive(at: now) else { return .none }
        switch lease.outlook {
        case .endsAtExpiry:
            guard let end = lease.expirationDate, end > now,
                  end.timeIntervalSince(now) <= endsSoonWindow else { return .none }
            return .endsSoon(tier: lease.tier, on: end)
        case .inGrace(let graceEnd):
            return .paymentIssue(tier: lease.tier, until: graceEnd)
        case .renewing, .unknown, .lifetime:
            return .none
        }
    }
}
