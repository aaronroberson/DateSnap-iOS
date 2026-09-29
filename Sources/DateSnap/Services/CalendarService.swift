import Foundation
import EventKit

// MARK: - Calendar Service Protocol
public protocol CalendarServiceProtocol: Sendable {
    func requestEventAccess() async throws -> Bool
    func authorizationStatus() -> EKAuthorizationStatus
    func fetchWritableCalendars() -> [EKCalendar]
    func defaultCalendar() -> EKCalendar?
    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String
    /// Rewrites an existing event (found by the identifier `createEvent` returned); recreates it if it was removed in Calendar.
    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String
    func deleteEvent(externalIdentifier: String) throws
}

// MARK: - Production Calendar Service
public final class CalendarService: CalendarServiceProtocol, @unchecked Sendable {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    // MARK: - Authorization
    public func authorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    public func requestEventAccess() async throws -> Bool {
        if #available(iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                return granted
            } catch {
                throw DateSnapError.calendar(.accessDenied)
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: DateSnapError.calendar(.eventCreationFailed(error.localizedDescription)))
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    // MARK: - Calendars
    public func fetchWritableCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event).filter { $0.allowsContentModifications }
    }

    public func defaultCalendar() -> EKCalendar? {
        return eventStore.defaultCalendarForNewEvents
    }

    // MARK: - Create Event
    public func createEvent(
        candidate: EventCandidate,
        calendar: EKCalendar? = nil,
        alarms: [TimeInterval] = [-86400, -7200]
    ) async throws -> String {
        let status = authorizationStatus()
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
        if !isAuthorized {
            let granted = try await requestEventAccess()
            guard granted else {
                throw DateSnapError.calendar(.accessDenied)
            }
        }

        let targetCalendar: EKCalendar
        if let cal = calendar {
            targetCalendar = cal
        } else if let def = defaultCalendar() {
            targetCalendar = def
        } else if let firstWritable = fetchWritableCalendars().first {
            targetCalendar = firstWritable
        } else {
            throw DateSnapError.calendar(.noWritableCalendarFound)
        }

        let event = EKEvent(eventStore: eventStore)
        event.calendar = targetCalendar
        apply(candidate: candidate, alarms: alarms, to: event)

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            let externalId = event.calendarItemExternalIdentifier ?? event.eventIdentifier ?? UUID().uuidString
            return externalId
        } catch {
            throw DateSnapError.calendar(.eventCreationFailed(error.localizedDescription))
        }
    }

    // MARK: - Update / Delete
    public func updateEvent(
        externalIdentifier: String,
        candidate: EventCandidate,
        calendar: EKCalendar? = nil,
        alarms: [TimeInterval]
    ) async throws -> String {
        guard let event = existingEvent(externalIdentifier) else {
            return try await createEvent(candidate: candidate, calendar: calendar, alarms: alarms)
        }
        if let calendar { event.calendar = calendar }
        apply(candidate: candidate, alarms: alarms, to: event)
        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            return event.calendarItemExternalIdentifier ?? externalIdentifier
        } catch {
            throw DateSnapError.calendar(.eventCreationFailed(error.localizedDescription))
        }
    }

    public func deleteEvent(externalIdentifier: String) throws {
        guard let event = existingEvent(externalIdentifier) else { return }
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
        } catch {
            throw DateSnapError.calendar(.eventCreationFailed(error.localizedDescription))
        }
    }

    private func existingEvent(_ externalIdentifier: String) -> EKEvent? {
        let items = eventStore.calendarItems(withExternalIdentifier: externalIdentifier)
        return items.compactMap { $0 as? EKEvent }.first ?? eventStore.event(withIdentifier: externalIdentifier)
    }

    private func apply(candidate: EventCandidate, alarms: [TimeInterval], to event: EKEvent) {
        event.title = candidate.title
        event.isAllDay = candidate.isAllDay
        event.startDate = candidate.startDate
        if candidate.isAllDay {
            event.endDate = candidate.endDate ?? candidate.startDate
        } else {
            event.endDate = candidate.endDate ?? candidate.startDate.addingTimeInterval(7200) // Default 2 hours
        }
        if let tz = candidate.timeZoneIdentifier, !candidate.isAllDay {
            event.timeZone = TimeZone(identifier: tz)
        }

        if let loc = candidate.location {
            if let venue = candidate.venueName, venue != loc {
                event.location = "\(venue), \(loc)"
            } else {
                event.location = loc
            }
        } else {
            event.location = candidate.venueName
        }

        var notesComponents: [String] = []
        if !candidate.notes.isEmpty {
            notesComponents.append(candidate.notes)
        }
        event.url = nil
        if let rsvp = candidate.rsvpUrl {
            notesComponents.append("RSVP / Tickets: \(rsvp)")
            if let url = URL(string: rsvp), rsvp.hasPrefix("http") {
                event.url = url
            }
        }
        if candidate.yearAssumed {
            notesComponents.append("Note: Year was inferred automatically by DateSnap.")
        }
        if !candidate.rawTextSnippet.isEmpty {
            notesComponents.append("Extracted Text:\n\(candidate.rawTextSnippet)")
        }
        event.notes = notesComponents.joined(separator: "\n\n")

        // Replace alarms (e.g. 1 day before: -86400, 2 hours before: -7200)
        event.alarms?.forEach { event.removeAlarm($0) }
        for offset in alarms {
            event.addAlarm(EKAlarm(relativeOffset: offset))
        }
    }
}
