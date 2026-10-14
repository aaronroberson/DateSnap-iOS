import Foundation
import EventKit

// MARK: - Default Calendar Store
/// Persists the user's Pencil’d-wide default destination calendar (e.g. "Home" instead of
/// whatever iOS happens to hand back). On-device only, like every other Pencil’d setting.
public struct DefaultCalendarStore: Sendable {
    public static let defaultsKey = "settings.defaultCalendarIdentifier"
    /// "Ask every time": new events start with no calendar and need one picked in review.
    /// (A new key; the earlier `settings.askEveryTimeCalendar` toggle never had a consumer.)
    public static let askEveryTimeKey = "settings.calendarAskEveryTime"
    private let defaultsSuiteName: String?

    public init(defaultsSuiteName: String? = nil) {
        self.defaultsSuiteName = defaultsSuiteName
    }

    private var defaults: UserDefaults {
        defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    /// The saved default calendar identifier, or `nil` when the user has not chosen one
    /// (Pencil’d then follows the iOS system default).
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
        defaults.removeObject(forKey: Self.askEveryTimeKey)
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

    /// Clears the choice; Pencil’d uses the automatic priority order again.
    public func reset() {
        setDefaultCalendarIdentifier(nil)
    }

    /// Whether new events must have their calendar picked in review.
    public func asksEveryTime() -> Bool {
        defaults.bool(forKey: Self.askEveryTimeKey)
    }

    /// Switches to "Ask every time" (clearing any chosen calendar).
    public func setAsksEveryTime() {
        setDefaultCalendarIdentifier(nil)
        defaults.set(true, forKey: Self.askEveryTimeKey)
    }
}

// MARK: - Destination Calendar Resolver
/// The order in which Pencil’d preselects a destination calendar for a calendar entry:
/// 1. The calendar already saved for this event (editing a saved event keeps its destination).
/// 2. The user's Pencil’d default calendar (Settings → Default Calendar), e.g. "Home". When set it
///    overrides the automatic order below. With "Ask every time", new events skip steps 2–5.
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
