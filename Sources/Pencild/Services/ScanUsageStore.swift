import Foundation

/// Counts scans that found a new event, per calendar month, on this device. Backs the free
/// plan's monthly scan allowance; stored locally like everything else in Pencil'd.
public final class ScanUsageStore: @unchecked Sendable {
    public static let shared = ScanUsageStore(defaults: .standard)

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let monthKey = "pencild.scanUsage.month"
    private let countKey = "pencild.scanUsage.count"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func scansUsed(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        defaults.string(forKey: monthKey) == Self.month(of: date, calendar: calendar) ? defaults.integer(forKey: countKey) : 0
    }

    func remainingFreeScans(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        max(0, PlanLimits.freeScansPerMonth - scansUsed(at: date, calendar: calendar))
    }

    func recordScan(at date: Date = Date(), calendar: Calendar = .current) {
        lock.lock()
        defer { lock.unlock() }
        let used = scansUsed(at: date, calendar: calendar)
        defaults.set(Self.month(of: date, calendar: calendar), forKey: monthKey)
        defaults.set(used + 1, forKey: countKey)
    }

    private static func month(of date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }
}
