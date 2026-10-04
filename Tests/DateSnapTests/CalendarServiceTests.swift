import Foundation
import EventKit
import Testing
@testable import DateSnap

@Suite("CalendarService Apply Fallback End Date Tests")
struct CalendarServiceTests {
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

        #expect(event.endDate == startDate)
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
