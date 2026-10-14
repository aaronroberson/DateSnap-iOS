import Foundation
import CoreGraphics
import Testing
@testable import Pencild

/// Work schedules and multi-date flyers: one event per dated entry, each with its own times.
/// `testAnchor` is Tuesday, September 1, 2026 at 12:00 UTC.
@Suite("Schedule extraction")
struct ScheduleExtractionTests {
    private func extract(_ lines: [String], locale: String = "en_US") -> [ExtractedCandidateData] {
        let result = makeOCR(lines.map { ($0, $0 == lines.first ? 0.06 : 0.03) })
        return EventExtractionCore.extract(from: result, locale: Locale(identifier: locale), anchor: testAnchor, calendar: testCalendar)
    }

    private func parts(_ date: Date) -> DateComponents {
        testCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    @Test("A scheduling-app screenshot yields one shift per day, skipping days off")
    func schedulingAppShifts() throws {
        let shifts = extract([
            "My Schedule",
            "Mon, Sep 7",
            "9:00 AM - 5:00 PM",
            "Cashier · Store 112",
            "Tue, Sep 8",
            "OFF",
            "Wed, Sep 9",
            "12:00 PM - 8:30 PM",
            "Stock",
            "Thu, Sep 10",
            "10:00 PM - 6:00 AM",
            "Overnight",
        ])
        #expect(shifts.count == 3)
        let first = try #require(shifts.first)
        #expect(parts(first.startDate).day == 7 && parts(first.startDate).hour == 9)
        #expect(parts(try #require(first.endDate)).hour == 17)
        #expect(first.title == "Work shift · Cashier")
        #expect(shifts[1].title == "Work shift · Stock")
        #expect(parts(shifts[1].startDate).day == 9 && parts(shifts[1].startDate).hour == 12)
        #expect(parts(try #require(shifts[1].endDate)).minute == 30)
        // Overnight: ends the next morning.
        let overnight = shifts[2]
        #expect(parts(overnight.startDate).hour == 22)
        #expect(parts(try #require(overnight.endDate)).day == 11)
        #expect(parts(try #require(overnight.endDate)).hour == 6)
        #expect(shifts.allSatisfy { !$0.isAllDay })
    }

    @Test("Roster rows with the date and times on one line each become a shift")
    func singleLineRoster() {
        let shifts = extract([
            "Weekly Roster",
            "Mon 9/7 9a-5p",
            "Tue 9/8 Off",
            "Wed 9/9 11a-7:30p",
            "Fri 9/11 7am-3pm",
        ])
        #expect(shifts.count == 3)
        #expect(shifts.map { parts($0.startDate).day } == [7, 9, 11])
        #expect(shifts.map { parts($0.startDate).hour } == [9, 11, 7])
        #expect(shifts.allSatisfy { $0.title == "Work shift" })
    }

    @Test("24-hour times and day-first dates are read correctly")
    func twentyFourHourRoster() {
        let shifts = extract([
            "Rota",
            "Mon 7 Sep 09:00-17:00",
            "Wed 9 Sep 13:30-22:00",
        ], locale: "en_GB")
        #expect(shifts.count == 2)
        #expect(parts(shifts[0].startDate).hour == 9)
        #expect(parts(shifts[1].startDate).hour == 13 && parts(shifts[1].startDate).minute == 30)
        #expect(shifts[1].endDate.map { parts($0).hour } == 22)
    }

    @Test("Weekday-only rows resolve against a 'Week of' header")
    func weekOfHeader() {
        let shifts = extract([
            "Schedule · Week of Sep 7",
            "Mon 9a-5p",
            "Wed 12p-8p",
            "Sat 8a-2p",
        ])
        #expect(shifts.map { parts($0.startDate).day } == [7, 9, 12])
    }

    @Test("Shifts earlier in the current week keep this year")
    func pastShiftsKeepTheYear() {
        let shifts = extract([
            "My Shifts",
            "Mon, Aug 31",
            "9:00 AM - 5:00 PM",
            "Thu, Sep 3",
            "9:00 AM - 5:00 PM",
        ])
        #expect(shifts.map { parts($0.startDate).year } == [2026, 2026])
    }

    @Test("A flyer listing several dates becomes one event per date with the shared time")
    func multiDateFlyer() {
        let events = extract([
            "JAZZ IN THE PARK",
            "Fridays: Sep 11, Sep 18, Sep 25 · 7 PM",
            "Riverside Amphitheater",
        ])
        #expect(events.count == 3)
        #expect(events.map { parts($0.startDate).day } == [11, 18, 25])
        #expect(events.allSatisfy { parts($0.startDate).hour == 19 })
        #expect(events.allSatisfy { $0.title == "JAZZ IN THE PARK" })
    }

    @Test("Each dated line of a syllabus is titled by its own label")
    func labelledEntries() {
        let events = extract([
            "BIO 101 Fall Schedule",
            "Sep 10 Quiz 1",
            "Sep 24 Lab report due",
            "Oct 8 Midterm exam",
        ])
        #expect(events.map(\.title) == ["Quiz 1", "Lab report due", "Midterm exam"])
        #expect(events.allSatisfy { $0.isAllDay })
    }

    @Test("A single flyer still produces exactly one event")
    func singleFlyerUnchanged() {
        let events = extract([
            "NEON SUNSET",
            "SATURDAY, OCTOBER 17, 2026",
            "DOORS 7:00 PM",
            "SHOW 8:30 PM",
            "SKYBAR PENTHOUSE",
        ])
        #expect(events.count == 1)
        #expect(events.first.map { parts($0.startDate).hour } == 20)
    }
}
