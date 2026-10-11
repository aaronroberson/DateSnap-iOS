import Foundation

// MARK: - Calendar Recommendation
/// Suggests a destination calendar from the user's own past explicit choices per event category.
/// Only calendar identifiers the user picked are stored (locally); calendar contents are never read.
public struct CalendarRecommendationService: Sendable {
    public static let defaultsKey = "advisor.calendarChoiceByCategory"
    private let defaultsSuiteName: String?

    public init(defaultsSuiteName: String? = nil) {
        self.defaultsSuiteName = defaultsSuiteName
    }

    private var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The calendar last chosen for this category, if it is still among the writable calendars.
    public func suggestedCalendarIdentifier(for category: EventCategory, available: [String]) -> String? {
        let map = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        guard let id = map[category.rawValue], available.contains(id) else { return nil }
        return id
    }

    /// Records an explicit save to `calendarIdentifier` for `category`.
    public func recordChoice(calendarIdentifier: String, for category: EventCategory) {
        var map = defaults.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
        map[category.rawValue] = calendarIdentifier
        defaults.set(map, forKey: Self.defaultsKey)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
