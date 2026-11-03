import Foundation

// MARK: - Event Duration Policy
/// The single source for "how long is an event with no stated end". Extraction, review and
/// `CalendarService` all use `fallback`, so no layer silently applies a different assumption.
/// Category durations are offered as editable suggestions only, until evaluation supports a better default.
/// Explicit end times found on flyers always take precedence over suggested durations.
public enum EventDurationPolicy {
    /// Labeled fallback when the flyer states no end time (2 hours).
    public static let fallback: TimeInterval = 2 * 3600

    /// Suggested length for dining events (~1.5 hours).
    public static let diningDuration: TimeInterval = 5400

    /// Suggested length for standard medical/personal appointments (1 hour).
    public static let appointmentDuration: TimeInterval = 3600

    /// Suggested length for a category, shown in review as an optional one-tap adjustment.
    /// Returns nil for .deadline and .other, where an arbitrary duration assumption is inappropriate.
    public static func suggestedDuration(for category: EventCategory, isDining: Bool = false) -> TimeInterval? {
        if isDining {
            return diningDuration
        }
        switch category {
        case .concert, .sports, .social: return 3 * 3600
        case .nightlife: return 4 * 3600
        case .conference, .festival: return 8 * 3600
        case .appointment: return appointmentDuration
        case .classOrWorkshop: return 2 * 3600
        case .deadline, .other: return nil
        }
    }

    /// Evaluates duration suggestion taking explicit end time into account.
    /// If an explicit end time was detected on the flyer, no suggestion is generated because
    /// the flyer's stated time has full precedence.
    public static func suggestedDuration(
        for category: EventCategory,
        hasExplicitEnd: Bool,
        isDining: Bool = false
    ) -> TimeInterval? {
        guard !hasExplicitEnd else { return nil }
        return suggestedDuration(for: category, isDining: isDining)
    }

    public static func fallbackEnd(for start: Date) -> Date {
        start.addingTimeInterval(fallback)
    }
}

/// A normalized interval used by Conflict Radar. Keeping this value type separate from SwiftData
/// makes overlap detection deterministic and easy to test without Calendar or persistence access.
public struct ScheduleInterval: Sendable, Equatable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    public let location: String?

    public init(id: String, title: String, start: Date, end: Date, location: String? = nil) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
    }
}

public enum ScheduleConflictKind: Sendable, Equatable {
    case overlap
    case insufficientGap
}

public struct ScheduleConflict: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: ScheduleConflictKind
    public let event: ScheduleInterval
    public let gap: TimeInterval?

    public init(kind: ScheduleConflictKind, event: ScheduleInterval, gap: TimeInterval? = nil) {
        self.kind = kind
        self.event = event
        self.gap = gap
        self.id = "\(kind)-\(event.id)"
    }
}

/// Detects collisions and short transition windows in the local Pencil’d schedule.
/// External Apple Calendar events are intentionally not included until read authorization and a
/// read-through service are added; the UI labels this boundary explicitly.
public enum ScheduleConflictAnalyzer {
    public static let defaultMinimumGap: TimeInterval = 15 * 60

    public static func interval(
        id: String,
        title: String,
        start: Date,
        end: Date?,
        assumedDuration: TimeInterval,
        location: String? = nil
    ) -> ScheduleInterval {
        ScheduleInterval(
            id: id,
            title: title,
            start: start,
            end: max(end ?? start.addingTimeInterval(assumedDuration), start),
            location: location
        )
    }

    public static func conflicts(
        for incoming: ScheduleInterval,
        against existing: [ScheduleInterval],
        minimumGap: TimeInterval = defaultMinimumGap
    ) -> [ScheduleConflict] {
        existing
            .filter { $0.id != incoming.id }
            .compactMap { event in
                if incoming.start < event.end && event.start < incoming.end {
                    return ScheduleConflict(kind: .overlap, event: event)
                }

                let gap: TimeInterval
                if event.start >= incoming.end {
                    gap = event.start.timeIntervalSince(incoming.end)
                } else if incoming.start >= event.end {
                    gap = incoming.start.timeIntervalSince(event.end)
                } else {
                    return nil
                }

                guard gap < minimumGap else { return nil }
                return ScheduleConflict(kind: .insufficientGap, event: event, gap: gap)
            }
            .sorted { $0.event.start < $1.event.start }
    }

    /// Returns the actual shared interval, rather than either event's full duration.
    /// Keeping this calculation here prevents the UI from overstating an overlap,
    /// especially when an event crosses midnight.
    public static func overlap(
        for incoming: ScheduleInterval,
        with existing: ScheduleInterval
    ) -> (start: Date, end: Date)? {
        let start = max(incoming.start, existing.start)
        let end = min(incoming.end, existing.end)
        guard start < end else { return nil }
        return (start, end)
    }
}
