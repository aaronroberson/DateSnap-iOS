import Foundation
import SwiftUI
import EventKit
import SwiftData

@MainActor
public final class EventReviewViewModel: ObservableObject {
    private let calendarService: CalendarServiceProtocol
    private let reminderService: ReminderServiceProtocol
    private let notificationService: NotificationServiceProtocol

    // MARK: - Editable State
    @Published public var title: String
    @Published public var startDate: Date
    @Published public var endDate: Date
    @Published public var isAllDay: Bool
    @Published public var location: String
    @Published public var venueName: String
    @Published public var rsvpUrl: String
    @Published public var notes: String
    @Published public var confidenceScore: Float
    @Published public var yearAssumed: Bool

    // MARK: - Ambiguity & Tiers
    @Published public var isAmbiguousDate: Bool = false
    @Published public var ambiguousFragment: String? = nil
    @Published public var timeZoneIdentifier: String = Calendar.current.timeZone.identifier
    @Published public var confidenceTier: ConfidenceTier = .high
    @Published public var isDraftOnly: Bool = false

    // MARK: - Destination Configurations
    @Published public var availableCalendars: [EKCalendar] = []
    @Published public var availableReminderLists: [EKCalendar] = []
    @Published public var selectedCalendar: EKCalendar? = nil
    @Published public var selectedReminderList: EKCalendar? = nil
    @Published public var selectedOffsets: [ReminderOffset] = ReminderOffset.defaultStaggered

    // MARK: - Status
    @Published public var isSaving: Bool = false
    @Published public var isSavedSuccessfully: Bool = false
    @Published public var errorMessage: String? = nil
    /// Set when the save failed because Calendar access is denied, so the view can route to recovery.
    @Published public var calendarAccessDenied: Bool = false
    /// Set when the event saved but local alerts could not be scheduled (notifications denied).
    @Published public var notificationsSkipped: Bool = false

    /// The candidate being reviewed. Edits are written back to it on save.
    public let candidate: EventCandidate
    public let sourceImage: UIImage?
    /// Raw OCR text from the scan, shown in the source-text drawer.
    public let rawText: String

    /// True when this candidate was already committed to Calendar; saving updates instead of creating.
    public var isEditingSavedEvent: Bool {
        candidate.savedEvent?.status == .saved && candidate.savedEvent?.externalCalendarEventId != nil
    }

    // MARK: - Initializer
    public init(candidate: EventCandidate, services: ServiceContainer, sourceImage: UIImage? = nil) {
        self.candidate = candidate
        self.sourceImage = sourceImage
        self.rawText = candidate.rawTextSnippet
        self.calendarService = services.calendar
        self.reminderService = services.reminders
        self.notificationService = services.notifications

        self.title = candidate.title
        self.startDate = candidate.startDate
        self.endDate = candidate.endDate ?? EventDurationPolicy.fallbackEnd(for: candidate.startDate)
        self.isAllDay = candidate.isAllDay
        self.location = candidate.location ?? ""
        self.venueName = candidate.venueName ?? ""
        self.rsvpUrl = candidate.rsvpUrl ?? ""
        self.notes = candidate.notes
        self.confidenceScore = candidate.confidenceScore
        self.yearAssumed = candidate.yearAssumed
        self.isAmbiguousDate = candidate.isAmbiguousDate
        self.ambiguousFragment = candidate.ambiguousFragment
        self.timeZoneIdentifier = candidate.timeZoneIdentifier ?? Calendar.current.timeZone.identifier
        self.confidenceTier = candidate.confidenceTier
        if let saved = candidate.savedEvent, !saved.alertOffsets.isEmpty {
            self.selectedOffsets = saved.alertOffsets.map { ReminderOffset.forInterval($0) }
        }

        loadCalendarData()
    }

    // MARK: - Month and Day Swap for Ambiguous Dates
    public func swapMonthAndDay() {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startDate)
        let oldMonth = comps.month ?? 1
        let oldDay = comps.day ?? 1
        guard oldDay <= 12 else { return }
        comps.month = oldDay
        comps.day = oldMonth

        if let newStart = calendar.date(from: comps) {
            let duration = endDate.timeIntervalSince(startDate)
            self.startDate = newStart
            self.endDate = newStart.addingTimeInterval(duration)
            self.isAmbiguousDate = false
            self.ambiguousFragment = nil
        }
    }

    /// Accepts the parsed date order as-is and clears the ambiguity prompt.
    public func confirmDateOrder() {
        isAmbiguousDate = false
        ambiguousFragment = nil
    }

    /// Keeps the end after the start when the start moves.
    public func startDateChanged(from oldValue: Date) {
        let duration = max(endDate.timeIntervalSince(oldValue), 0)
        endDate = startDate.addingTimeInterval(duration == 0 ? EventDurationPolicy.fallback : duration)
    }

    // MARK: - Load Available Calendars & Lists
    public func loadCalendarData() {
        self.availableCalendars = calendarService.fetchWritableCalendars()
        let savedTitle = candidate.savedEvent?.targetCalendar
        self.selectedCalendar = availableCalendars.first(where: { $0.title == savedTitle })
            ?? calendarService.defaultCalendar()
            ?? availableCalendars.first

        self.availableReminderLists = reminderService.fetchReminderLists()
        let savedList = candidate.savedEvent?.targetRemindersList
        self.selectedReminderList = availableReminderLists.first(where: { $0.title == savedList })
            ?? reminderService.defaultReminderList()
            ?? availableReminderLists.first
    }

    /// Requests Calendar access if it has never been asked, then refreshes the destination pickers.
    public func prepareDestinations() async {
        if calendarService.authorizationStatus() == .notDetermined {
            _ = try? await calendarService.requestEventAccess()
        }
        if reminderService.authorizationStatus() == .notDetermined {
            _ = try? await reminderService.requestReminderAccess()
        }
        loadCalendarData()
    }

    // MARK: - Alert Offset Management (Max 3)
    public func addOffset(_ offset: ReminderOffset) {
        guard selectedOffsets.count < 3 else {
            errorMessage = "A maximum of 3 reminder alerts can be scheduled per event."
            return
        }
        if !selectedOffsets.contains(where: { $0.timeInterval == offset.timeInterval }) {
            selectedOffsets.append(offset)
        }
    }

    public func removeOffset(at index: Int) {
        guard index < selectedOffsets.count else { return }
        selectedOffsets.remove(at: index)
    }

    // MARK: - Apply Edits
    private func applyEdits() {
        candidate.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Event" : title
        candidate.startDate = startDate
        candidate.endDate = isAllDay ? nil : max(endDate, startDate)
        candidate.isAllDay = isAllDay
        candidate.location = location.isEmpty ? nil : location
        candidate.venueName = venueName.isEmpty ? nil : venueName
        candidate.rsvpUrl = rsvpUrl.isEmpty ? nil : rsvpUrl
        candidate.notes = notes
        candidate.isAmbiguousDate = isAmbiguousDate
        candidate.ambiguousFragment = ambiguousFragment
        candidate.timeZoneIdentifier = timeZoneIdentifier
    }

    private func savedEventRecord(in context: ModelContext?) -> SavedEvent {
        if let existing = candidate.savedEvent {
            return existing
        }
        let record = SavedEvent(candidate: candidate)
        context?.insert(candidate)
        context?.insert(record)
        candidate.savedEvent = record
        return record
    }

    // MARK: - Save Draft (no Calendar / Reminders writes)
    public func saveDraft(modelContext: ModelContext?) {
        applyEdits()
        let record = savedEventRecord(in: modelContext)
        if record.status != .saved {
            record.status = .draft
        }
        record.alertOffsets = selectedOffsets.map(\.timeInterval)
        record.targetCalendar = selectedCalendar?.title ?? record.targetCalendar
        record.targetRemindersList = selectedReminderList?.title ?? record.targetRemindersList
        try? modelContext?.save()
        isDraftOnly = true
        isSavedSuccessfully = true
    }

    /// Removes an unsaved candidate from the review queue.
    public func discard(modelContext: ModelContext?) {
        guard candidate.savedEvent == nil, let context = modelContext else { return }
        context.delete(candidate)
        try? context.save()
    }

    // MARK: - Commit to Apple Calendar & Reminders
    /// Writes the reviewed event to Calendar, Reminders and local alerts. Only called on explicit user confirmation.
    public func commitEvent(modelContext: ModelContext? = nil) async -> Bool {
        isSaving = true
        errorMessage = nil
        calendarAccessDenied = false
        notificationsSkipped = false
        defer { isSaving = false }

        applyEdits()
        let offsets = selectedOffsets
        let alarmIntervals = offsets.map { $0.alarmOffset(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) }
        let existing = candidate.savedEvent

        // 1. Apple Calendar (create, or update the event this candidate already wrote)
        let externalCalendarId: String
        do {
            if let existingId = existing?.externalCalendarEventId {
                externalCalendarId = try await calendarService.updateEvent(
                    externalIdentifier: existingId,
                    candidate: candidate,
                    calendar: selectedCalendar,
                    alarms: alarmIntervals
                )
            } else {
                externalCalendarId = try await calendarService.createEvent(
                    candidate: candidate,
                    calendar: selectedCalendar,
                    alarms: alarmIntervals
                )
            }
        } catch DateSnapError.calendar(.accessDenied) {
            calendarAccessDenied = true
            errorMessage = DateSnapError.calendar(.accessDenied).localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        // 2. Apple Reminders (non-fatal if the user denied Reminders)
        var reminderIds = existing?.externalReminderIds ?? []
        do {
            if let existingReminder = reminderIds.first {
                let id = try await reminderService.updateReminder(
                    externalIdentifier: existingReminder,
                    candidate: candidate,
                    list: selectedReminderList,
                    offsets: offsets
                )
                reminderIds = [id]
            } else {
                let id = try await reminderService.createReminder(
                    candidate: candidate,
                    list: selectedReminderList,
                    offsets: offsets
                )
                reminderIds = [id]
            }
        } catch {
            print("Notice: Reminder creation skipped or denied: \(error.localizedDescription)")
        }

        // 3. Local push alerts, replacing any previously scheduled for this event
        notificationService.removePendingNotifications(identifiers: existing?.scheduledNotificationIds ?? [])
        let scheduledNotifIds = await scheduleAlerts(offsets: offsets)

        // 4. Persist to SwiftData
        let record = savedEventRecord(in: modelContext)
        record.externalCalendarEventId = externalCalendarId
        record.externalReminderIds = reminderIds
        record.scheduledNotificationIds = scheduledNotifIds
        record.alertOffsets = offsets.map(\.timeInterval)
        record.targetCalendar = selectedCalendar?.title ?? calendarService.defaultCalendar()?.title ?? "Default Calendar"
        record.targetRemindersList = selectedReminderList?.title ?? reminderService.defaultReminderList()?.title ?? "Reminders"
        record.status = .saved
        try? modelContext?.save()

        isDraftOnly = false
        isSavedSuccessfully = true
        return true
    }

    private func scheduleAlerts(offsets: [ReminderOffset]) async -> [String] {
        let triggerDates = offsets.map { $0.triggerDate(forEventStart: candidate.startDate, isAllDay: candidate.isAllDay) }
        do {
            return try await notificationService.scheduleLocalNotifications(
                title: candidate.title,
                body: EventAlertText.body(for: candidate),
                triggerDates: triggerDates,
                eventId: candidate.id
            )
        } catch {
            notificationsSkipped = true
            return []
        }
    }
}

// MARK: - Shared Alert Copy
enum EventAlertText {
    @MainActor
    static func body(for candidate: EventCandidate) -> String {
        let when = candidate.isAllDay
            ? candidate.startDate.formatted(date: .abbreviated, time: .omitted)
            : candidate.startDate.formatted(date: .abbreviated, time: .shortened)
        if let place = candidate.venueName ?? candidate.location {
            return "\(when) · \(place)"
        }
        return when
    }
}
