import Foundation

// MARK: - Entitlement Cache

/// `UserDefaults`-backed persistence for `SubscriptionLease`. Tests inject a `UserDefaults`
/// suite so they don't pollute the standard defaults.
public enum EntitlementCache {
    private static let key = "entitlement.lease.v1"

    /// The defaults instance used for storage. Overridden by tests via `setDefaults(_:)`.
    nonisolated(unsafe) private static var defaults: UserDefaults = .standard

    /// For tests: swap in an isolated `UserDefaults` suite.
    public static func setDefaults(_ defaults: UserDefaults) {
        Self.defaults = defaults
    }

    /// Restores the standard defaults (called by test teardown / production).
    public static func useStandardDefaults() {
        Self.defaults = .standard
    }

    public static func load() -> SubscriptionLease? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(SubscriptionLease.self, from: data)
    }

    public static func save(_ entitlement: SubscriptionLease) {
        if let data = try? encoder.encode(entitlement) {
            defaults.set(data, forKey: key)
        }
    }

    public static func clear() {
        defaults.removeObject(forKey: key)
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
}
