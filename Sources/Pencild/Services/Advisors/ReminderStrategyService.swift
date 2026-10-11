import Foundation

// MARK: - Reminder Strategy
/// An editable, suggested alert plan. Offsets always come from `ReminderOffset.catalog` (the app-supported set),
/// never more than three, and a separate deadline reminder is proposed only when the flyer states a deadline.
public struct ReminderPlan: Sendable, Equatable {
    public var offsets: [ReminderOffset]
    /// When to remind the user to RSVP/register, if the flyer has a deadline still in the future.
    public var deadlineReminder: Date?
    /// Short explanation shown beside the suggestion.
    public var rationale: String
}

public enum ReminderStrategyService {
    public static func plan(
        category: EventCategory,
        start: Date,
        isAllDay: Bool,
        rsvpDeadline: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReminderPlan {
        let preferred: [ReminderOffset]
        let rationale: String
        switch category {
        case .appointment:
            preferred = [.oneDayBefore, .oneHourBefore]
            rationale = "Appointments: a day-before heads-up and an hour to get there."
        case .concert, .nightlife, .sports:
            preferred = [.oneDayBefore, .twoHoursBefore]
            rationale = "Shows and games: plan the day before, leave two hours ahead."
        case .festival:
            preferred = [.twoDaysBefore, .oneDayBefore, .threeHoursBefore]
            rationale = "Festivals: time to arrange tickets and travel."
        case .conference, .classOrWorkshop:
            preferred = [.oneDayBefore, .oneHourBefore]
            rationale = "Sessions: prepare the day before, an hour's notice on the day."
        case .deadline:
            preferred = [.oneWeekBefore, .twoDaysBefore, .oneDayBefore]
            rationale = "Deadlines: early warning plus a final reminder."
        case .social, .other:
            preferred = ReminderOffset.defaultStaggered
            rationale = "A day-before reminder and a two-hour heads-up."
        }

        // Drop alerts that would already have fired; a very near event gets one short alert.
        var offsets = preferred.filter { $0.triggerDate(forEventStart: start, isAllDay: isAllDay, calendar: calendar) > now }
        if offsets.isEmpty {
            let fallback: [ReminderOffset] = [.thirtyMinutesBefore, .fifteenMinutesBefore, .atEvent]
            offsets = Array(fallback.filter { $0.triggerDate(forEventStart: start, isAllDay: isAllDay, calendar: calendar) > now }.prefix(1))
        }

        var deadlineReminder: Date? = nil
        if let deadline = rsvpDeadline {
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: deadline))
                .flatMap { calendar.date(bySettingHour: 9, minute: 0, second: 0, of: $0) }
            if let dayBefore, dayBefore > now {
                deadlineReminder = dayBefore
            } else if deadline > now {
                deadlineReminder = deadline
            }
        }

        return ReminderPlan(offsets: Array(offsets.prefix(3)), deadlineReminder: deadlineReminder, rationale: rationale)
    }
}
