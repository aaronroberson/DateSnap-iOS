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

// MARK: - Mock EKEventStore
private final class MockEventStore: EKEventStore, @unchecked Sendable {
    var stubbedEvent: EKEvent?
    var shouldFailRemove = false
    var removeCalled = false
    var removeSpanPassed: EKSpan?
    var removeCommitPassed: Bool?

    override func calendarItems(withExternalIdentifier externalIdentifier: String) -> [EKCalendarItem] {
        if let event = stubbedEvent {
            return [event]
        }
        return []
    }

    override func event(withIdentifier identifier: String) -> EKEvent? {
        return stubbedEvent
    }

    override func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        removeCalled = true
        removeSpanPassed = span
        removeCommitPassed = commit

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
        let mockStore = MockEventStore()
        let event = EKEvent(eventStore: mockStore)
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
        let mockStore = MockEventStore()
        let event = EKEvent(eventStore: mockStore)
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
        let mockStore = MockEventStore()
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
    private let calendarService = CalendarService()
    private let eventStore = EKEventStore()

    @Test("Non-all-day candidate without end date uses EventDurationPolicy fallback")
    func nonAllDayFallbackEnd() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let candidate = EventCandidate(
            title: "Non All-Day Meeting",
            startDate: startDate,
            endDate: nil,
            isAllDay: false
        )
        let event = EKEvent(eventStore: eventStore)
        calendarService.apply(candidate: candidate, alarms: [], to: event)

        let expectedEndDate = EventDurationPolicy.fallbackEnd(for: startDate)
        #expect(event.endDate == expectedEndDate)
    }

    @Test("All-day candidate without end date defaults end date to start date")
    func allDayFallbackEnd() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let candidate = EventCandidate(
            title: "All-Day Conference",
            startDate: startDate,
            endDate: nil,
            isAllDay: true
        )
        let event = EKEvent(eventStore: eventStore)
        calendarService.apply(candidate: candidate, alarms: [], to: event)

        // The fallback keeps the end on the start date's day (not the timed
        // EventDurationPolicy fallback). EKEvent normalizes all-day end dates
        // to 23:59:59 local time, so compare calendar days, not instants.
        let calendar = Calendar.current
        #expect(event.isAllDay)
        if let endDate = event.endDate {
            #expect(calendar.startOfDay(for: endDate) == calendar.startOfDay(for: startDate))
            #expect(endDate >= startDate)
        } else {
            Issue.record("All-day fallback must set an end date")
        }
    }

    @Test("Candidate with explicit end date preserves provided end date")
    func explicitEndDatePreserved() {
        let startDate = Date(timeIntervalSince1970: 1_700_000_000)
        let explicitEndDate = startDate.addingTimeInterval(7200)
        let candidate = EventCandidate(
            title: "Workshop",
            startDate: startDate,
            endDate: explicitEndDate,
            isAllDay: false
        )
        let event = EKEvent(eventStore: eventStore)
        calendarService.apply(candidate: candidate, alarms: [], to: event)

        #expect(event.endDate == explicitEndDate)
    }
}
