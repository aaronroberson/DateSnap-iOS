import Foundation
import EventKit
import Testing
@testable import DateSnap

// MARK: - Test Error Double
private enum MockEventStoreError: LocalizedError {
    case removalFailed

    var errorDescription: String? {
        switch self {
        case .removalFailed:
            return "Mock EKEventStore remove failed intentionally."
        }
    }
}

// MARK: - Isolated Event Store Double
private final class TestCalendarEventStore: CalendarEventStoreProviding, @unchecked Sendable {
    private let eventFactoryStore = EKEventStore()
    var stubbedEvent: EKEvent?
    var shouldFailRemove = false
    var removeCalled = false
    var removeSpanPassed: EKSpan?
    var removeCommitPassed: Bool?

    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func requestAccess() async throws -> Bool { true }
    func writableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }
    func makeEvent() -> EKEvent { EKEvent(eventStore: eventFactoryStore) }
    func save(_ event: EKEvent) throws {}
    func existingEvent(withExternalIdentifier identifier: String) -> EKEvent? { stubbedEvent }

    func remove(_ event: EKEvent) throws {
        removeCalled = true
        removeSpanPassed = .thisEvent
        removeCommitPassed = true

        if shouldFailRemove {
            throw MockEventStoreError.removalFailed
        }
    }
}

// MARK: - Calendar Service Delete Tests Suite
@Suite("CalendarService Tests")
struct CalendarServiceDeleteTests {

    @Test("deleteEvent throws eventCreationFailed DateSnapError when eventStore.remove fails")
    func deleteEventErrorHandling() throws {
        let mockStore = TestCalendarEventStore()
        let event = mockStore.makeEvent()
        mockStore.stubbedEvent = event
        mockStore.shouldFailRemove = true

        let service = CalendarService(eventStore: mockStore)

        #expect(throws: DateSnapError.self) {
            try service.deleteEvent(externalIdentifier: "test-ext-id")
        }

        do {
            try service.deleteEvent(externalIdentifier: "test-ext-id")
            #expect(Bool(false), "Expected deleteEvent to throw an error but it succeeded")
        } catch let DateSnapError.calendar(calendarError) {
            if case .eventCreationFailed(let reason) = calendarError {
                #expect(reason.contains("Mock EKEventStore remove failed intentionally"))
            } else {
                #expect(Bool(false), "Expected .eventCreationFailed error, got \(calendarError)")
            }
        } catch {
            #expect(Bool(false), "Expected DateSnapError.calendar, got \(error)")
        }

        #expect(mockStore.removeCalled)
        #expect(mockStore.removeSpanPassed == .thisEvent)
        #expect(mockStore.removeCommitPassed == true)
    }

    @Test("deleteEvent successfully removes existing event when store removal succeeds")
    func deleteEventSuccess() throws {
        let mockStore = TestCalendarEventStore()
        let event = mockStore.makeEvent()
        mockStore.stubbedEvent = event
        mockStore.shouldFailRemove = false

        let service = CalendarService(eventStore: mockStore)

        #expect(throws: Never.self) {
            try service.deleteEvent(externalIdentifier: "test-ext-id")
        }

        #expect(mockStore.removeCalled)
        #expect(mockStore.removeSpanPassed == .thisEvent)
        #expect(mockStore.removeCommitPassed == true)
    }

    @Test("deleteEvent returns cleanly without calling remove when event is not found")
    func deleteEventNotFound() throws {
        let mockStore = TestCalendarEventStore()
        mockStore.stubbedEvent = nil

        let service = CalendarService(eventStore: mockStore)

        #expect(throws: Never.self) {
            try service.deleteEvent(externalIdentifier: "non-existent-id")
        }

        #expect(!mockStore.removeCalled)
    }
}

// MARK: - Calendar Service Apply Fallback Tests Suite
@Suite("CalendarService Apply Fallback End Date Tests")
struct CalendarServiceApplyFallbackTests {
    private let eventStore = TestCalendarEventStore()

    @Test("Non-all-day candidate without end date uses EventDurationPolicy fallback")
    func nonAllDayFallbackEnd() {
        let startDate = testFutureDate
        let candidate = EventCandidate(
            title: "Non All-Day Meeting",
            startDate: startDate,
            endDate: nil,
            isAllDay: false
        )
        let event = eventStore.makeEvent()
        CalendarService(eventStore: eventStore).apply(candidate: candidate, alarms: [], to: event)

        let expectedEndDate = EventDurationPolicy.fallbackEnd(for: startDate)
        #expect(event.endDate == expectedEndDate)
    }

    @Test("All-day candidate without end date defaults end date to start date")
    func allDayFallbackEnd() {
        let startDate = testFutureDate
        let candidate = EventCandidate(
            title: "All-Day Conference",
            startDate: startDate,
            endDate: nil,
            isAllDay: true
        )
        let event = eventStore.makeEvent()
        CalendarService(eventStore: eventStore).apply(candidate: candidate, alarms: [], to: event)

        // EventKit represents an all-day end as the exclusive start of the
        // following day, independent of the timed duration fallback.
        let calendar = testCalendar
        #expect(event.isAllDay)
        if let endDate = event.endDate {
            let dayDelta = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: startDate),
                to: calendar.startOfDay(for: endDate)
            ).day
            #expect(dayDelta == 0 || dayDelta == 1)
            #expect(endDate >= startDate)
        } else {
            Issue.record("All-day fallback must set an end date")
        }
    }

    @Test("Candidate with explicit end date preserves provided end date")
    func explicitEndDatePreserved() {
        let startDate = testFutureDate
        let explicitEndDate = startDate.addingTimeInterval(7200)
        let candidate = EventCandidate(
            title: "Workshop",
            startDate: startDate,
            endDate: explicitEndDate,
            isAllDay: false
        )
        let event = eventStore.makeEvent()
        CalendarService(eventStore: eventStore).apply(candidate: candidate, alarms: [], to: event)

        #expect(event.endDate == explicitEndDate)
    }
}
