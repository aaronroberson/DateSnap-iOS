import Foundation
import SwiftData

// MARK: - Saved Event Lifecycle Actions
/// Mutations on persisted `SavedEvent` records that must stay in step with Calendar, Reminders and local alerts.
@MainActor
struct SavedEventActions {
    let services: ServiceContainer
    let modelContext: ModelContext
    var saveOperation: (() throws -> Void)?

    init(
        services: ServiceContainer,
        modelContext: ModelContext,
        saveOperation: (() throws -> Void)? = nil
    ) {
        self.services = services
        self.modelContext = modelContext
        self.saveOperation = saveOperation
    }

    private func save() throws {
        if let saveOperation {
            try saveOperation()
        } else {
            try modelContext.save()
        }
    }

    /// Finds the saved record for a candidate id (the id carried by `DateSnapEvent` and notification payloads).
    static func savedEvent(candidateId: String, in context: ModelContext) -> SavedEvent? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == candidateId })
        return (try? context.fetch(descriptor))?.first?.savedEvent
    }

    static func candidate(id: String, in context: ModelContext) -> EventCandidate? {
        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    /// Replaces the event's Calendar alarms, Reminder schedule and pending local notifications.
    @discardableResult
    func rescheduleAlerts(for saved: SavedEvent, offsets: [ReminderOffset]) async -> MutationResult {
        guard let candidate = saved.candidate else {
            return .failure(MutationFailure(message: "The event record is missing its event details."))
        }
        let alarms = offsets.map { $0.alarmOffset(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) }
        let priorCalendarId = saved.externalCalendarEventId
        let priorReminderIds = saved.externalReminderIds
        let priorNotificationIds = saved.scheduledNotificationIds
        let priorOffsets = saved.alertOffsets
        var issues: [String] = []

        if saved.status == .saved {
            if let calendarId = saved.externalCalendarEventId {
                do {
                    saved.externalCalendarEventId = try await services.calendar.updateEvent(
                        externalIdentifier: calendarId, candidate: candidate, calendar: nil, alarms: alarms
                    )
                } catch {
                    issues.append("Calendar: \(error.localizedDescription)")
                }
            }
            if let reminderId = saved.externalReminderIds.first {
                do {
                    saved.externalReminderIds = [try await services.reminders.updateReminder(
                        externalIdentifier: reminderId, candidate: candidate, list: nil, offsets: offsets
                    )]
                } catch {
                    issues.append("Reminders: \(error.localizedDescription)")
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
                issues.append("Local notifications: \(error.localizedDescription)")
            }
        }

        saved.alertOffsets = offsets.map(\.timeInterval)
        do {
            try save()
        } catch {
            saved.externalCalendarEventId = priorCalendarId
            saved.externalReminderIds = priorReminderIds
            saved.scheduledNotificationIds = priorNotificationIds
            saved.alertOffsets = priorOffsets
            let detail = issues.isEmpty ? "" : " External changes also reported: \(issues.joined(separator: "; "))."
            return .failure(MutationFailure(message: "Could not save the reminder schedule: \(error.localizedDescription).\(detail)"))
        }
        return issues.isEmpty ? .success : .partial(issues)
    }

    /// Moves a record between Saved / Draft / Archived. Archiving silences pending local alerts.
    func setStatus(_ status: SavedEventStatus, for saved: SavedEvent) -> MutationResult {
        let priorStatus = saved.status
        let priorNotificationIds = saved.scheduledNotificationIds
        if status == .archived {
            saved.scheduledNotificationIds = []
        }
        saved.status = status
        do {
            try save()
            if status == .archived {
                services.notifications.removePendingNotifications(identifiers: priorNotificationIds)
            }
            return .success
        } catch {
            saved.status = priorStatus
            saved.scheduledNotificationIds = priorNotificationIds
            return .failure(MutationFailure(error))
        }
    }

    /// Deletes the DateSnap record. When `removeFromCalendar` is set, the Calendar event and reminder are removed too.
    func delete(_ saved: SavedEvent, removeFromCalendar: Bool) -> MutationResult {
        services.notifications.removePendingNotifications(identifiers: saved.scheduledNotificationIds)
        saved.scheduledNotificationIds = []
        var issues: [String] = []
        if removeFromCalendar {
            if let calendarId = saved.externalCalendarEventId {
                do {
                    try services.calendar.deleteEvent(externalIdentifier: calendarId)
                    saved.externalCalendarEventId = nil
                } catch {
                    issues.append("Calendar: \(error.localizedDescription)")
                }
            }
            var retainedReminderIds: [String] = []
            for reminderId in saved.externalReminderIds {
                do {
                    try services.reminders.deleteReminder(externalIdentifier: reminderId)
                } catch {
                    retainedReminderIds.append(reminderId)
                    issues.append("Reminders: \(error.localizedDescription)")
                }
            }
            saved.externalReminderIds = retainedReminderIds
            if let deadlineReminderId = saved.deadlineReminderId {
                do {
                    try services.reminders.deleteReminder(externalIdentifier: deadlineReminderId)
                    saved.deadlineReminderId = nil
                } catch {
                    issues.append("RSVP deadline reminder: \(error.localizedDescription)")
                }
            }
        }
        if issues.isEmpty {
            if let candidate = saved.candidate {
                modelContext.delete(candidate)
            } else {
                modelContext.delete(saved)
            }
        }
        do {
            try save()
            return issues.isEmpty ? .success : .partial(issues)
        } catch {
            // Nothing in this method was committed: the save is the first and only
            // persistence point, so rolling back restores the record, its external
            // identifiers, and its notification ids exactly as they were before the
            // attempted deletion. (Re-inserting a deleted model does not reliably
            // resurrect it in SwiftData.)
            modelContext.rollback()
            return .failure(MutationFailure(message: "Could not save the event changes: \(error.localizedDescription)"))
        }
    }

    /// Erases every scan, candidate and saved record DateSnap holds (Calendar and Reminders entries are kept).
    func eraseAllLocalData() -> MutationResult {
        var saved: [SavedEvent] = []
        var candidates: [EventCandidate] = []
        var assets: [ScannedAsset] = []
        var interpretations: [InterpretationRecord] = []
        do {
            saved = try modelContext.fetch(FetchDescriptor<SavedEvent>())
            candidates = try modelContext.fetch(FetchDescriptor<EventCandidate>())
            assets = try modelContext.fetch(FetchDescriptor<ScannedAsset>())
            interpretations = try modelContext.fetch(FetchDescriptor<InterpretationRecord>())
            let notificationIds = saved.flatMap(\.scheduledNotificationIds)
            try modelContext.delete(model: InterpretationRecord.self)
            try modelContext.delete(model: SavedEvent.self)
            try modelContext.delete(model: EventCandidate.self)
            try modelContext.delete(model: ScannedAsset.self)
            try save()
            services.notifications.removePendingNotifications(identifiers: notificationIds)
            return .success
        } catch {
            for candidate in candidates { modelContext.insert(candidate) }
            for item in saved { modelContext.insert(item) }
            for asset in assets { modelContext.insert(asset) }
            for item in interpretations { modelContext.insert(item) }
            return .failure(MutationFailure(message: "Could not erase local DateSnap data: \(error.localizedDescription)"))
        }
    }

    /// Clears scan text and persisted OCR evidence while leaving saved events intact.
    func clearScanCache() -> MutationResult {
        var priorText: [(ScannedAsset, String)] = []
        var interpretations: [InterpretationRecord] = []
        do {
            let assets = try modelContext.fetch(FetchDescriptor<ScannedAsset>())
            priorText = assets.map { ($0, $0.rawOcrText) }
            interpretations = try modelContext.fetch(FetchDescriptor<InterpretationRecord>())
            for asset in assets {
                asset.rawOcrText = ""
            }
            try modelContext.delete(model: InterpretationRecord.self)
            try save()
            return .success
        } catch {
            for (asset, previous) in priorText {
                asset.rawOcrText = previous
            }
            for item in interpretations { modelContext.insert(item) }
            return .failure(MutationFailure(message: "Could not clear the scan cache: \(error.localizedDescription)"))
        }
    }
}
