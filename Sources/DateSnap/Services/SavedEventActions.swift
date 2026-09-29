import Foundation
import SwiftData

// MARK: - Saved Event Lifecycle Actions
/// Mutations on persisted `SavedEvent` records that must stay in step with Calendar, Reminders and local alerts.
@MainActor
struct SavedEventActions {
    let services: ServiceContainer
    let modelContext: ModelContext

    /// Finds the saved record for a candidate id (the id carried by `DateSnapEvent` and notification payloads).
    static func savedEvent(candidateId: String, in context: ModelContext) -> SavedEvent? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == candidateId })
        return (try? context.fetch(descriptor))?.first?.savedEvent
    }

    static func candidate(id: String, in context: ModelContext) -> EventCandidate? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// Replaces the alert schedule on the calendar event, the reminder and the pending local notifications.
    /// Returns false when local notifications could not be scheduled (e.g. permission denied).
    @discardableResult
    func rescheduleAlerts(for saved: SavedEvent, offsets: [ReminderOffset]) async throws -> Bool {
        guard let candidate = saved.candidate else { return false }
        let alarms = offsets.map { $0.alarmOffset(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) }

        if saved.status == .saved {
            if let calendarId = saved.externalCalendarEventId {
                saved.externalCalendarEventId = try await services.calendar.updateEvent(
                    externalIdentifier: calendarId, candidate: candidate, calendar: nil, alarms: alarms
                )
            }
            if let reminderId = saved.externalReminderIds.first {
                let id = try? await services.reminders.updateReminder(
                    externalIdentifier: reminderId, candidate: candidate, list: nil, offsets: offsets
                )
                if let id { saved.externalReminderIds = [id] }
            }
        }

        services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
        var notificationsScheduled = true
        if saved.status == .saved {
            do {
                saved.scheduledNotificationIds = try await services.notifications.scheduleLocalNotifications(
                    title: candidate.title,
                    body: EventAlertText.body(for: candidate),
                    triggerDates: offsets.map { $0.triggerDate(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) },
                    eventId: candidate.id
                )
            } catch {
                saved.scheduledNotificationIds = []
                notificationsScheduled = false
            }
        }

        saved.alertOffsets = offsets.map(\.timeInterval)
        try? modelContext.save()
        return notificationsScheduled
    }

    /// Moves a record between Saved / Draft / Archived. Archiving silences pending local alerts.
    func setStatus(_ status: SavedEventStatus, for saved: SavedEvent) {
        if status == .archived {
            services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
            saved.scheduledNotificationIds = []
        }
        saved.status = status
        try? modelContext.save()
    }

    /// Deletes the DateSnap record. When `removeFromCalendar` is set, the Calendar event and reminder are removed too.
    func delete(_ saved: SavedEvent, removeFromCalendar: Bool) {
        services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
        if removeFromCalendar {
            if let calendarId = saved.externalCalendarEventId {
                try? services.calendar.deleteEvent(externalIdentifier: calendarId)
            }
            for reminderId in saved.externalReminderIds {
                try? services.reminders.deleteReminder(externalIdentifier: reminderId)
            }
        }
        if let candidate = saved.candidate {
            modelContext.delete(candidate) // cascades to the SavedEvent
        } else {
            modelContext.delete(saved)
        }
        try? modelContext.save()
    }

    /// Erases every scan, candidate and saved record DateSnap holds (Calendar and Reminders entries are kept).
    func eraseAllLocalData() {
        let saved = (try? modelContext.fetch(FetchDescriptor<SavedEvent>())) ?? []
        services.notifications.removePendingNotifications(identifiers: saved.flatMap(\.scheduledNotificationIds))
        try? modelContext.delete(model: InterpretationRecord.self)
        try? modelContext.delete(model: SavedEvent.self)
        try? modelContext.delete(model: EventCandidate.self)
        try? modelContext.delete(model: ScannedAsset.self)
        try? modelContext.save()
    }
}
