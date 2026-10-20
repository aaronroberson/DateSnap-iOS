import Foundation

// MARK: - Renewal Outlook

/// What StoreKit says will happen to a paid plan when its current period ends. It decides how
/// long a previously verified entitlement may keep working when StoreKit can't be reached.
public enum RenewalOutlook: Codable, Sendable, Equatable {
    /// Auto-renew is on; the plan will normally continue.
    case renewing
    /// The subscriber cancelled; access ends exactly at the expiration date.
    case endsAtExpiry
    /// Renewal payment failed but Apple's billing grace period keeps access until the date.
    case inGrace(until: Date)
    /// StoreKit gave no usable renewal information.
    case unknown
    /// A one-time purchase that never expires.
    case lifetime
}

// MARK: - Subscription Lease

/// The last StoreKit-verified entitlement plus how long it may be trusted offline. Persisted by
/// `EntitlementCache`. A live StoreKit answer always overrides it; the lease only decides what
/// happens while StoreKit can't answer.
public struct SubscriptionLease: Codable, Sendable, Equatable {
    public let tier: SubscriptionTier
    public let outlook: RenewalOutlook
    public let expirationDate: Date?
    public let evaluatedAt: Date

    /// Renewals can lag the expiration date, and the user may be travelling or offline, so a
    /// plan that is renewing (or whose outlook is unknown) stays usable this long past expiry.
    public static let renewalTolerance: TimeInterval = 3 * 24 * 60 * 60
    /// With no expiration date at all, trust the last successful check for this long.
    public static let unknownTolerance: TimeInterval = 7 * 24 * 60 * 60

    public init(tier: SubscriptionTier, outlook: RenewalOutlook, expirationDate: Date?, evaluatedAt: Date) {
        self.tier = tier
        self.outlook = outlook
        self.expirationDate = expirationDate
        self.evaluatedAt = evaluatedAt
    }

    /// When offline access ends. `.distantFuture` for lifetime purchases.
    public var accessEnd: Date {
        switch outlook {
        case .lifetime:
            return .distantFuture
        case .endsAtExpiry:
            return expirationDate ?? evaluatedAt.addingTimeInterval(Self.unknownTolerance)
        case .inGrace(let graceEnd):
            return max(expirationDate ?? graceEnd, graceEnd)
        case .renewing, .unknown:
            return expirationDate.map { $0.addingTimeInterval(Self.renewalTolerance) }
                ?? evaluatedAt.addingTimeInterval(Self.unknownTolerance)
        }
    }

    /// Whether this lease may stand in for a StoreKit answer at `now`. A clock earlier than the
    /// evaluation time means the device clock was moved back, so the lease can't be trusted.
    public func isActive(at now: Date = Date()) -> Bool {
        evaluatedAt <= now && now < accessEnd
    }
}
