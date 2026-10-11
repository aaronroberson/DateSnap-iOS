import Foundation

// MARK: - Event Duration Policy
/// The single source for "how long is an event with no stated end". Extraction, review and
/// `CalendarService` all use `fallback`, so no layer silently applies a different assumption.
/// Category durations are offered as editable suggestions only, until evaluation supports a better default.
public enum EventDurationPolicy {
    /// Labeled fallback when the flyer states no end time.
    public static let fallback: TimeInterval = 2 * 3600

    /// Suggested length for a category, shown in review as an optional one-tap adjustment.
    public static func suggestedDuration(for category: EventCategory) -> TimeInterval? {
        switch category {
        case .concert, .sports, .social: return 3 * 3600
        case .nightlife: return 4 * 3600
        case .conference, .festival: return 8 * 3600
        case .appointment: return 3600
        case .classOrWorkshop: return 2 * 3600
        case .deadline, .other: return nil
        }
    }

    public static func fallbackEnd(for start: Date) -> Date {
        start.addingTimeInterval(fallback)
    }
}
