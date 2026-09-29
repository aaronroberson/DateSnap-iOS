import Foundation

// MARK: - Intelligence Usage Policy
/// Local daily budgets for automation-style work (e.g. likely-event triage checks) so convenience features
/// stay light on battery. Counts are stored on device only; single-scan review is never budgeted.
public struct IntelligenceUsagePolicy: Sendable {
    public static let defaultsKey = "intelligence.usage"
    private let defaultsSuiteName: String?

    public init(defaultsSuiteName: String? = nil) {
        self.defaultsSuiteName = defaultsSuiteName
    }

    private var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// Daily allowance of a feature's unit of work for a tier (0 when the tier doesn't include it).
    public static func dailyLimit(for feature: PremiumFeature, tier: SubscriptionTier) -> Int {
        guard tier.includes(feature) else { return 0 }
        switch feature {
        case .likelyEventTriage: return tier == .premium ? 120 : 30
        default: return .max
        }
    }

    /// Consumes `count` units if the budget allows; returns how many were granted.
    public func consume(_ feature: PremiumFeature, count: Int, tier: SubscriptionTier, now: Date = Date()) -> Int {
        let limit = Self.dailyLimit(for: feature, tier: tier)
        guard limit > 0, count > 0 else { return 0 }
        guard limit != .max else { return count }
        let key = "\(Self.defaultsKey).\(feature.rawValue).\(Self.dayStamp(now))"
        let used = defaults.integer(forKey: key)
        let granted = max(0, min(count, limit - used))
        if granted > 0 { defaults.set(used + granted, forKey: key) }
        return granted
    }

    static func dayStamp(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
