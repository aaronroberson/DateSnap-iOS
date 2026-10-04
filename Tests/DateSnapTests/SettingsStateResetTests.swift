import Foundation
import Testing
@testable import DateSnap

@Suite("SettingsState Reset Tests")
@MainActor
struct SettingsStateResetTests {

    @Test("Initial state has default reminder configuration")
    func testInitialReminderDefaults() {
        let settings = SettingsState()
        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)
        #expect(settings.allDayDayOf == true)
        #expect(settings.allDayDayBefore == true)
        #expect(settings.routePrimary == .calendar)
        #expect(settings.alertSound == "Crystal Chime (Haptic Pulse)")
    }

    @Test("resetReminderDefaults restores all affected properties after mutation")
    func testResetReminderDefaults() {
        let settings = SettingsState()

        // Mutate all affected variables to non-default values
        settings.timedPreset = .minimal
        settings.timedAlerts = []
        settings.allDayDayOf = false
        settings.allDayDayBefore = false
        settings.routePrimary = .push
        settings.alertSound = "Custom Siren"

        // Perform reset
        settings.resetReminderDefaults()

        // Assert exact restoration
        #expect(settings.timedPreset == .standard)
        #expect(settings.allDayDayOf == true)
        #expect(settings.allDayDayBefore == true)
        #expect(settings.routePrimary == .calendar)
        #expect(settings.alertSound == "Crystal Chime (Haptic Pulse)")

        // Assert detailed timedAlerts properties
        #expect(settings.timedAlerts.count == 2)

        let alert1 = settings.timedAlerts[0]
        #expect(alert1.glyph == "bell.badge.fill")
        #expect(alert1.title == "1 Day Before")
        #expect(alert1.channel == "Apple Reminders")
        let alert1Hour = Calendar.current.component(.hour, from: alert1.time)
        #expect(alert1Hour == 9)

        let alert2 = settings.timedAlerts[1]
        #expect(alert2.glyph == "hourglass")
        #expect(alert2.title == "2 Hours Before")
        #expect(alert2.channel == "Calendar Notification")
        let alert2Hour = Calendar.current.component(.hour, from: alert2.time)
        let alert2Minute = Calendar.current.component(.minute, from: alert2.time)
        #expect(alert2Hour == 18)
        #expect(alert2Minute == 30)
    }
}
