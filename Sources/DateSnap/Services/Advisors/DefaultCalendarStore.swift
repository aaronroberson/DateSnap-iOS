import Foundation
import EventKit

// MARK: - Default Calendar Store
/// Persists the user's DateSnap-wide default destination calendar (e.g. "Home" instead of
/// whatever iOS happens to hand back). On-device only, like every other DateSnap setting.
public struct DefaultCalendarStore: Sendable {
    public static let defaultsKey = "settings.defaultCalendarIdentifier"
    private let defaultsSuiteName: String?

    public init(defaultsSuiteName: String? = nil) {
        self.defaultsSuiteName = defaultsSuiteName
    }

    private var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The saved default calendar identifier, or `nil` when the user has not chosen one
    /// (DateSnap then follows the iOS system default).
    public func defaultCalendarIdentifier() -> String? {
        defaults.string(forKey: Self.defaultsKey)
    }

    /// The display title of the saved default calendar, if one is set. Used by the
    /// Settings row before Calendar access is granted.
    public func defaultCalendarTitle() -> String? {
        guard defaultCalendarIdentifier() != nil else { return nil }
        return defaults.string(forKey: Self.defaultsKey + ".title")
    }

    /// Persists the chosen default calendar. `title` is a convenience mirror so Settings
    /// can show the choice without Calendar access.
    public func setDefaultCalendarIdentifier(_ identifier: String?, title: String? = nil) {
        if let identifier {
            defaults.set(identifier, forKey: Self.defaultsKey)
            if let title {
                defaults.set(title, forKey: Self.defaultsKey + ".title")
            }
        } else {
            defaults.removeObject(forKey: Self.defaultsKey)
            defaults.removeObject(forKey: Self.defaultsKey + ".title")
        }
    }

    /// Clears the choice; DateSnap follows the iOS system default again.
    public func reset() {
        setDefaultCalendarIdentifier(nil)
    }
}

// MARK: - Destination Calendar Resolver
/// The order in which DateSnap preselects a destination calendar for a calendar entry:
/// 1. The calendar already saved for this event (editing a saved event keeps its destination).
/// 2. The user's DateSnap default calendar (Settings → Destinations), e.g. "Home".
/// 3. The learned per-category choice (`CalendarRecommendationService`).
/// 4. The iOS system default calendar.
/// 5. The first writable calendar (deterministic fallback).
public enum DestinationCalendarResolver {
    /// Anything with a stable identifier and display title; `EKCalendar` conforms.
    /// (EventKit identifiers are never nil, so the requirement is non-optional.)
    public protocol Option {
        var calendarIdentifier: String { get }
        var title: String { get }
    }

    static func select<T: Option>(
        _ available: [T],
        savedTitle: String?,
        userDefaultIdentifier: String?,
        recommendedIdentifier: String?,
        systemDefault: T?
    ) -> T? {
        available.first { $0.title == savedTitle }
            ?? available.first { $0.calendarIdentifier == userDefaultIdentifier }
            ?? available.first { $0.calendarIdentifier == recommendedIdentifier }
            ?? systemDefault
            ?? available.first
    }
}

extension EKCalendar: DestinationCalendarResolver.Option {}
