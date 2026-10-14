import Foundation
import Testing
@testable import Pencild

@Suite("Shared rules")
struct SharedRulesTests {
    @Test("Maps link joins venue and address, skipping blanks and the location placeholder")
    func mapsLink() throws {
        let url = try #require(PencildLinks.maps(["Central Park", "", PencildEvent.locationPlaceholder, "New York, NY"]))
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
        #expect(url.host == "maps.apple.com")
        #expect(query == "Central Park, New York, NY")
        #expect(PencildLinks.maps(["", PencildEvent.locationPlaceholder]) == nil)
    }

    @Test("Support mail goes to the one support address with the subject filled in")
    func supportMail() throws {
        let url = try #require(PencildLinks.supportMail(subject: "Pencil’d Support Request"))
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(url.scheme == "mailto")
        #expect(components?.path == PencildLinks.supportEmail)
        #expect(components?.queryItems?.first?.value == "Pencil’d Support Request")
    }

    @Test("Standard is never locked; other presets lock above the plan's alert limit")
    func presetLocking() {
        #expect(!ReminderPreset.defaultPreset.isLocked(maxAlerts: PlanLimits.freeAlertsPerEvent))
        #expect(ReminderPreset.defaultPreset.offsets(limitedTo: 1)?.count == 1)
        #expect(ReminderPreset.travelHeavy.isLocked(maxAlerts: PlanLimits.freeAlertsPerEvent))
        #expect(!ReminderPreset.travelHeavy.isLocked(maxAlerts: PlanLimits.paidAlertsPerEvent))
        #expect(!ReminderPreset.dayOfOnly.isLocked(maxAlerts: PlanLimits.freeAlertsPerEvent))
        #expect(PlanLimits.canUpgradeAlerts(from: PlanLimits.freeAlertsPerEvent))
        #expect(!PlanLimits.canUpgradeAlerts(from: PlanLimits.paidAlertsPerEvent))
    }

    @Test("Upcoming starts at the beginning of today, for Agenda and the History filter alike")
    func upcoming() throws {
        let now = try #require(testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 4, hour: 15)))
        let earlierToday = try #require(testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 4, hour: 9)))
        let yesterday = try #require(testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 3, hour: 20)))
        #expect(AgendaDateFilter.upcoming.includes(earlierToday, relativeTo: now, calendar: testCalendar))
        #expect(!AgendaDateFilter.upcoming.includes(yesterday, relativeTo: now, calendar: testCalendar))
    }

    @Test("All-day alerts and the RSVP day-before reminder share one hour")
    func allDayHour() throws {
        let deadline = try #require(testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 10)))
        let fire = ReminderOffset.oneDayBefore.triggerDate(forEventStart: deadline, isAllDay: true, calendar: testCalendar)
        #expect(testCalendar.component(.hour, from: fire) == ReminderOffset.allDayAlertHour)
        #expect(testCalendar.component(.day, from: fire) == 9)
    }
}
