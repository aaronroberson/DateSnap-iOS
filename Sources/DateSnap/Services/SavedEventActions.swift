import Foundation
import SwiftData

// MARK: - Saved Event Lifecycle Actions
/// Mutations on persisted SavedEvent records that must stay in step with Calendar, Reminders and local alerts.
@MainActor
struct SavedEventActions {
    let services: ServiceContainer
    let modelContext: ModelContext
    private let saveContext: () throws -> Void

    init(services: ServiceContainer, modelContext: ModelContext, saveContext: (() throws -> Void)? = nil) {
        self.services = services
        self.modelContext = modelContext
        self.saveContext = saveContext ?? { try modelContext.save() }
    }

    /// Finds the saved record for a candidate id (the id carried by DateSnapEvent and notification payloads).
    static func savedEvent(candidateId: String, in context: ModelContext) -> SavedEvent? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == candidateId })
        return (try? context.fetch(descriptor))?.first?.savedEvent
    }

    static func candidate(id: String, in context: ModelContext) -> EventCandidate? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// Replaces calendar, reminder and local notification schedules, reporting partial failures.
    @discardableResult
    func rescheduleAlerts(for saved: SavedEvent, offsets: [ReminderOffset]) async -> MutationResult {
        guard let candidate = saved.candidate else {
            return .failure(MutationFailure(message: "The saved event no longer has its event details."))
        }
        let alarms = offsets.map { $0.alarmOffset(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) }
        var failures: [String] = []

        if saved.status == .saved {
            if let calendarId = saved.externalCalendarEventId {
                do {
                    saved.externalCalendarEventId = try await services.calendar.updateEvent(
                        externalIdentifier: calendarId, candidate: candidate, calendar: nil, alarms: alarms
                    )
                } catch {
                    return .failure(MutationFailure(error))
                }
            }
            if let reminderId = saved.externalReminderIds.first {
                do {
                    let id = try await services.reminders.updateReminder(
                        externalIdentifier: reminderId, candidate: candidate, list: nil, offsets: offsets
                    )
                    saved.externalReminderIds = [id]
                } catch {
                    failures.append("Reminders: \(error.localizedDescription)")
                }
            }
        }

        services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
        saved.scheduledNotificationIds = []
        if saved.status == .saved {
            do {
                saved.scheduledNotificationIds = try await services.notifications.scheduleLocalNotifications(
                    title: candidate.title,
                    body: EventAlertText.body(for: candidate),
                    triggerDates: offsets.map { $0.triggerDate(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) },
                    eventId: candidate.id,
                    actionURL: candidate.rsvpUrl
                )
            } catch {
                saved.scheduledNotificationIds = []
                failures.append("Local notifications: \(error.localizedDescription)")
            }
        }

        saved.alertOffsets = offsets.map(\.timeInterval)
        let persistence = MutationResult.perform(saveContext)
        guard case .success = persistence else { return persistence }
        return failures.isEmpty ? .success : .partial(failures)
    }

    /// Moves a record between Saved / Draft / Archived. Archiving silences pending local alerts.
    @discardableResult
    func setStatus(_ status: SavedEventStatus, for saved: SavedEvent) -> MutationResult {
        if status == .archived {
            services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
            saved.scheduledNotificationIds = []
        }
        saved.status = status
        return MutationResult.perform(saveContext)
    }

    /// Deletes the DateSnap record and, when requested, its Calendar event and Reminders.
    @discardableResult
    func delete(_ saved: SavedEvent, removeFromCalendar: Bool) -> MutationResult {
        services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
        var failures: [String] = []

        if removeFromCalendar {
            if let calendarId = saved.externalCalendarEventId {
                do {
                    try services.calendar.deleteEvent(externalIdentifier: calendarId)
                    saved.externalCalendarEventId = nil
                } catch {
                    failures.append("Calendar event: \(error.localizedDescription)")
                }
            }

            var remainingReminderIDs: [String] = []
            for reminderId in saved.externalReminderIds {
                do {
                    try services.reminders.deleteReminder(externalIdentifier: reminderId)
                } catch {
                    remainingReminderIDs.append(reminderId)
                    failures.append("Reminder \(reminderId): \(error.localizedDescription)")
                }
            }
            saved.externalReminderIds = remainingReminderIDs

            if let deadlineId = saved.deadlineReminderId {
                do {
                    try services.reminders.deleteReminder(externalIdentifier: deadlineId)
                    saved.deadlineReminderId = nil
                } catch {
                    failures.append("Deadline reminder \(deadlineId): \(error.localizedDescription)")
                }
            }
        }

        if !failures.isEmpty {
            let savedIDs = MutationResult.perform(saveContext)
            guard case .success = savedIDs else { return savedIDs }
            return .partial(failures)
        }

        if let candidate = saved.candidate {
            modelContext.delete(candidate) // cascades to the SavedEvent
        } else {
            modelContext.delete(saved)
        }
        return MutationResult.perform(saveContext)
    }

    /// Erases every scan, candidate and saved record DateSnap holds (Calendar and Reminders entries are kept).
    @discardableResult
    func eraseAllLocalData() -> MutationResult {
        let saved: [SavedEvent]
        do {
            saved = try modelContext.fetch(FetchDescriptor<SavedEvent>())
            try modelContext.delete(model: InterpretationRecord.self)
            try modelContext.delete(model: SavedEvent.self)
            try modelContext.delete(model: EventCandidate.self)
            try modelContext.delete(model: ScannedAsset.self)
        } catch {
            return .failure(MutationFailure(error))
        }

        let result = MutationResult.perform(saveContext)
        guard case .success = result else { return result }
        services.notifications.removePendingNotifications(identifiers: saved.flatMap(\.scheduledNotificationIds))
        return .success
    }

    /// Clears OCR text and interpretation evidence while preserving event records.
    @discardableResult
    func clearScanCache() -> MutationResult {
        do {
            let assets = try modelContext.fetch(FetchDescriptor<ScannedAsset>())
            let alreadyClean = assets.filter { $0.rawOcrText.isEmpty }.count
            for asset in assets {
                asset.rawOcrText = ""
            }
            try modelContext.delete(model: InterpretationRecord.self)
            try saveContext()
            if alreadyClean > 0 {
                return .partial(["\(alreadyClean) scan records already had empty OCR text"])
            }
            return .success
        } catch {
            return .failure(MutationFailure(error))
        }
    }
}
