import Foundation
import EventKit

// MARK: - Reminder Offset Model
public struct ReminderOffset: Sendable, Hashable, Identifiable {
    public var id: String { "\(label)-\(timeInterval)" }
    public let timeInterval: TimeInterval // Negative seconds relative to event start
    public let label: String

    public init(timeInterval: TimeInterval, label: String) {
        self.timeInterval = timeInterval
        self.label = label
    }

    public static let oneDayBefore = ReminderOffset(timeInterval: -86400, label: "1 day before")
    public static let twoHoursBefore = ReminderOffset(timeInterval: -7200, label: "2 hours before")
    public static let oneHourBefore = ReminderOffset(timeInterval: -3600, label: "1 hour before")
    public static let thirtyMinutesBefore = ReminderOffset(timeInterval: -1800, label: "30 minutes before")
    public static let fifteenMinutesBefore = ReminderOffset(timeInterval: -900, label: "15 minutes before")
    public static let atEvent = ReminderOffset(timeInterval: 0, label: "At time of event")

    public static let twoDaysBefore = ReminderOffset(timeInterval: -172800, label: "2 days before")
    public static let threeHoursBefore = ReminderOffset(timeInterval: -10800, label: "3 hours before")
    public static let fortyFiveMinutesBefore = ReminderOffset(timeInterval: -2700, label: "45 minutes before")
    public static let oneWeekBefore = ReminderOffset(timeInterval: -604800, label: "1 week before")

    public static let defaultStaggered: [ReminderOffset] = [
        .oneDayBefore,
        .twoHoursBefore
    ]

    /// Every offset the schedule editors can pick from, earliest first.
    public static let catalog: [ReminderOffset] = [
        .oneWeekBefore, .twoDaysBefore, .oneDayBefore, .threeHoursBefore, .twoHoursBefore,
        .oneHourBefore, .fortyFiveMinutesBefore, .thirtyMinutesBefore, .fifteenMinutesBefore, .atEvent
    ]

    /// Resolves a stored interval back to a labelled offset, synthesizing a label for unknown values.
    public static func forInterval(_ interval: TimeInterval) -> ReminderOffset {
        if let known = catalog.first(where: { $0.timeInterval == interval }) {
            return known
        }
        let minutes = Int(abs(interval) / 60)
        if minutes % 1440 == 0 { return ReminderOffset(timeInterval: interval, label: "\(minutes / 1440) days before") }
        if minutes % 60 == 0 { return ReminderOffset(timeInterval: interval, label: "\(minutes / 60) hours before") }
        return ReminderOffset(timeInterval: interval, label: "\(minutes) minutes before")
    }

    /// When this alert fires for an event. All-day events anchor alerts to 9:00 AM local on the offset day.
    public func triggerDate(forEventStart start: Date, isAllDay: Bool, calendar: Calendar = .current) -> Date {
        guard isAllDay else { return start.addingTimeInterval(timeInterval) }
        let dayStart = calendar.startOfDay(for: start)
        let offsetDays = Int((timeInterval / 86400).rounded(.down))
        let alertDay = calendar.date(byAdding: .day, value: offsetDays, to: dayStart) ?? dayStart
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: alertDay) ?? alertDay
    }

    /// Relative offset (from the event start) that EventKit alarms should use so they match `triggerDate`.
    public func alarmOffset(forEventStart start: Date, isAllDay: Bool) -> TimeInterval {
        triggerDate(forEventStart: start, isAllDay: isAllDay).timeIntervalSince(start)
    }
}

// MARK: - Reminder Service Protocol
public protocol ReminderServiceProtocol: Sendable {
    func requestReminderAccess() async throws -> Bool
    func authorizationStatus() -> EKAuthorizationStatus
    func fetchReminderLists() -> [EKCalendar]
    func defaultReminderList() -> EKCalendar?
    func createReminder(
        candidate: EventCandidate,
        list: EKCalendar?,
        offsets: [ReminderOffset]
    ) async throws -> String
    /// Rewrites an existing reminder (found by the identifier `createReminder` returned); recreates it if it is gone.
    func updateReminder(
        externalIdentifier: String,
        candidate: EventCandidate,
        list: EKCalendar?,
        offsets: [ReminderOffset]
    ) async throws -> String
    func deleteReminder(externalIdentifier: String) throws
    /// A standalone to-do (e.g. "RSVP: …") due at `due`, separate from the event reminder.
    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String
}

// MARK: - Production Reminder Service
public final class ReminderService: ReminderServiceProtocol, @unchecked Sendable {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - Authorization
    public func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    public func requestReminderAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                return granted
            } catch {
                throw DateSnapError.reminders(.accessDenied)
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: DateSnapError.reminders(.reminderCreationFailed(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Lists
    public func fetchReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder).filter { $0.allowsContentModifications }
    }

    public func defaultReminderList() -> EKCalendar? {
        return eventStore.defaultCalendarForNewReminders()
    }

    // MARK: - Create Reminder
    public func createReminder(
        candidate: EventCandidate,
        list: EKCalendar? = nil,
        offsets: [ReminderOffset] = ReminderOffset.defaultStaggered
    ) async throws -> String {
        guard offsets.count <= 3 else {
            throw DateSnapError.reminders(.maxOffsetsExceeded)
        }

        let status = authorizationStatus()
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
        if !isAuthorized {
            let granted = try await requestReminderAccess()
            guard granted else {
                throw DateSnapError.reminders(.accessDenied)
            }
        }

        let targetList: EKCalendar
        if let list = list {
            targetList = list
        } else if let def = defaultReminderList() {
            targetList = def
        } else if let firstWritable = fetchReminderLists().first {
            targetList = firstWritable
        } else {
            throw DateSnapError.reminders(.noListFound)
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = targetList
        apply(candidate: candidate, offsets: offsets, to: reminder)

        do {
            try eventStore.save(reminder, commit: true)
            let identifier = reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier
            return identifier
        } catch {
            throw DateSnapError.reminders(.reminderCreationFailed(error.localizedDescription))
        }
    }

    // MARK: - Deadline Reminder
    public func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar? = nil) async throws -> String {
        if authorizationStatus() != .fullAccess {
            guard try await requestReminderAccess() else { throw DateSnapError.reminders(.accessDenied) }
        }
        guard let targetList = list ?? defaultReminderList() ?? fetchReminderLists().first else {
            throw DateSnapError.reminders(.noListFound)
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = targetList
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .timeZone], from: due)
        reminder.dueDateComponents = components
        reminder.addAlarm(EKAlarm(absoluteDate: due))
        if let url, let link = URL(string: url.hasPrefix("http") ? url : "https://\(url)") {
            reminder.url = link
            reminder.notes = "Link from the flyer: \(url)\nCaptured on-device by DateSnap"
        } else {
            reminder.notes = "Captured on-device by DateSnap"
        }
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemExternalIdentifier ?? reminder.calendarItemIdentifier
        } catch {
            throw DateSnapError.reminders(.reminderCreationFailed(error.localizedDescription))
        }
    }

    // MARK: - Update / Delete
    public func updateReminder(
        externalIdentifier: String,
        candidate: EventCandidate,
        list: EKCalendar? = nil,
        offsets: [ReminderOffset]
    ) async throws -> String {
        guard offsets.count <= 3 else {
            throw DateSnapError.reminders(.maxOffsetsExceeded)
        }
        guard let reminder = existingReminder(externalIdentifier) else {
            return try await createReminder(candidate: candidate, list: list, offsets: offsets)
        }
        if let list { reminder.calendar = list }
        apply(candidate: candidate, offsets: offsets, to: reminder)
        do {
            try eventStore.save(reminder, commit: true)
            return reminder.calendarItemExternalIdentifier ?? externalIdentifier
        } catch {
            throw DateSnapError.reminders(.reminderCreationFailed(error.localizedDescription))
        }
    }

    public func deleteReminder(externalIdentifier: String) throws {
        guard let reminder = existingReminder(externalIdentifier) else { return }
        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            throw DateSnapError.reminders(.reminderCreationFailed(error.localizedDescription))
        }
    }

    private func existingReminder(_ externalIdentifier: String) -> EKReminder? {
        let items = eventStore.calendarItems(withExternalIdentifier: externalIdentifier)
        return items.compactMap { $0 as? EKReminder }.first
            ?? (eventStore.calendarItem(withIdentifier: externalIdentifier) as? EKReminder)
    }

    private func apply(candidate: EventCandidate, offsets: [ReminderOffset], to reminder: EKReminder) {
        reminder.title = "Event: \(candidate.title)"

        let calendar = Calendar.current
        let fields: Set<Calendar.Component> = candidate.isAllDay
            ? [.year, .month, .day]
            : [.year, .month, .day, .hour, .minute, .timeZone]
        let dateComponents = calendar.dateComponents(fields, from: candidate.startDate)
        reminder.dueDateComponents = dateComponents
        reminder.startDateComponents = dateComponents

        var notesList: [String] = []
        if let venue = candidate.venueName {
            notesList.append("Venue: \(venue)")
        }
        if let loc = candidate.location {
            notesList.append("Address: \(loc)")
        }
        if !candidate.notes.isEmpty {
            notesList.append(candidate.notes)
        }
        if let rsvp = candidate.rsvpUrl {
            notesList.append("RSVP/Tickets: \(rsvp)")
        }
        notesList.append("Captured on-device by DateSnap")
        reminder.notes = notesList.joined(separator: "\n")

        // Up to 3 staggered alarms, replacing any existing ones
        reminder.alarms?.forEach { reminder.removeAlarm($0) }
        for offset in offsets {
            let fireDate = offset.triggerDate(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay)
            reminder.addAlarm(EKAlarm(absoluteDate: fireDate))
        }
    }
}
