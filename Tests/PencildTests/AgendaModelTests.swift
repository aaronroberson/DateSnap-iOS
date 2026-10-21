import Foundation
import Testing
@testable import Pencild

@Suite("Agenda calendar math")
struct AgendaCalendarTests {
    /// Gregorian, Sunday-first, UTC, so results don't depend on the test machine's locale.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test("Month grid pads the first row back to the first weekday")
    func monthGridLeadingDays() {
        // October 1, 2026 is a Thursday: four leading days (Sun–Wed) from September.
        let grid = AgendaCalendar.monthGrid(for: date(2026, 10, 14), calendar: calendar)
        #expect(grid.count == 4 + 31)
        #expect(grid.first == date(2026, 9, 27))
        #expect(grid.last == date(2026, 10, 31))
    }

    @Test("Week runs seven days from the locale's first weekday")
    func weekContainingDate() {
        let week = AgendaCalendar.week(containing: date(2026, 10, 14), calendar: calendar)
        #expect(week.count == 7)
        #expect(week.first == date(2026, 10, 11))
        #expect(week.last == date(2026, 10, 17))
    }

    @Test("Shifting a month selects the first of the new month")
    func shiftMonth() {
        let next = AgendaCalendar.shift(date(2026, 10, 14), mode: .month, by: 1, calendar: calendar)
        #expect(next.selected == date(2026, 11, 1))
        let previous = AgendaCalendar.shift(date(2026, 1, 31), mode: .month, by: -1, calendar: calendar)
        #expect(previous.selected == date(2025, 12, 1))
    }

    @Test("Shifting a day view moves by week and selects the week's first day")
    func shiftDay() {
        let next = AgendaCalendar.shift(date(2026, 10, 14), mode: .day, by: 1, calendar: calendar)
        #expect(next.visible == date(2026, 10, 21))
        #expect(next.selected == date(2026, 10, 18))
    }
}

@Suite("Agenda event filter")
struct AgendaEventFilterTests {
    @Test("Choosing All clears status and smart filter")
    func selectingAllClearsSelections() {
        var filter = AgendaEventFilter()
        filter.smartFilter = .repeating
        let all = filter.selecting(.all)
        #expect(all.status == nil)
        #expect(all.smartFilter == nil)
    }

    @Test("Leaving All returns to Saved")
    func leavingAllRestoresSaved() {
        let filter = AgendaEventFilter().selecting(.all).selecting(.today)
        #expect(filter.status == .saved)
        #expect(filter.dateRange == .today)
    }

    @Test("Counts only selections that differ from the default")
    func activeCount() {
        #expect(AgendaEventFilter().activeCount == 0)
        var filter = AgendaEventFilter()
        filter.searchText = "jazz"
        filter.dateRange = .past
        #expect(filter.activeCount == 2)
        #expect(filter.isNarrowed)
    }

    @Test("Empty copy follows status and date range")
    func emptyCopy() {
        var filter = AgendaEventFilter()
        #expect(filter.emptyTitle == "Your agenda is clear")
        filter.dateRange = .past
        #expect(filter.emptyTitle == "No past events")
        filter.status = .draft
        #expect(filter.emptyTitle == "No draft events")
    }
}
