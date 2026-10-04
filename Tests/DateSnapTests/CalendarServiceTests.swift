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

// MARK: - Calendar Service Tests Suite
@Suite("CalendarService Tests")
struct CalendarServiceTests {

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
