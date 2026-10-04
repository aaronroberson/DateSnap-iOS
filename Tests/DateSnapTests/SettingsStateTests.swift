import Foundation
import Testing
@testable import DateSnap

@Suite("SettingsState tests")
@MainActor
struct SettingsStateTests {

    @Test("SettingsState initializes with expected default property values")
    func testInitialDefaults() {
        let settings = SettingsState()

        #expect(settings.isAnnual == true)
        #expect(settings.autoRenewal == true)
        #expect(settings.planName == "DateSnap Plus (Annual)")
        #expect(settings.planPrice == "$29.99")

        #expect(settings.screenshotAutoPurge == true)
        #expect(settings.faceIDProtection == true)
        #expect(settings.purgeWindow == .immediate)

        #expect(settings.scanProfile == .review)
        #expect(settings.captureScopeCameraPhotos == false)
        #expect(settings.includeAirDropShared == true)
        #expect(settings.confidence == 85)
        #expect(settings.draftLowConfidence == true)

        #expect(settings.quickExtractionPrompt == true)
        #expect(settings.eveningDigest == true)
        #expect(settings.pauseOnLowPower == true)

        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)
        #expect(settings.timedAlerts[0].title == "1 Day Before")
        #expect(settings.timedAlerts[1].title == "2 Hours Before")
        #expect(settings.timedAlerts[2].title == "30 Minutes Before")

        #expect(settings.allDayDayOf == true)
        #expect(settings.allDayDayBefore == true)
        #expect(settings.routePrimary == .calendar)
        #expect(settings.alertSound == "Crystal Chime (Haptic Pulse)")
        #expect(settings.pendingRoute == nil)
    }

    @Test("applyTimedPreset(.minimal) reduces timedAlerts count from 3 to 1")
    func testApplyTimedPresetMinimal() {
        let settings = SettingsState()
        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)

        settings.applyTimedPreset(.minimal)

        #expect(settings.timedPreset == .minimal)
        #expect(settings.timedAlerts.count == 1)
        #expect(settings.timedAlerts[0].title == "1 Day Before")
    }

    @Test("applyTimedPreset(.standard) reduces timedAlerts count from 3 to 2")
    func testApplyTimedPresetStandard() {
        let settings = SettingsState()
        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)

        settings.applyTimedPreset(.standard)

        #expect(settings.timedPreset == .standard)
        #expect(settings.timedAlerts.count == 2)
        #expect(settings.timedAlerts[0].title == "1 Day Before")
        #expect(settings.timedAlerts[1].title == "2 Hours Before")
    }

    @Test("applyTimedPreset(.thorough) preserves all 3 timedAlerts from initial state")
    func testApplyTimedPresetThorough() {
        let settings = SettingsState()
        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)

        settings.applyTimedPreset(.thorough)

        #expect(settings.timedPreset == .thorough)
        #expect(settings.timedAlerts.count == 3)
        #expect(settings.timedAlerts[0].title == "1 Day Before")
        #expect(settings.timedAlerts[1].title == "2 Hours Before")
        #expect(settings.timedAlerts[2].title == "30 Minutes Before")
    }

    @Test("Sequential preset applications and resetReminderDefaults operate correctly")
    func testSequentialApplyAndReset() {
        let settings = SettingsState()

        // Apply minimal -> count is 1
        settings.applyTimedPreset(.minimal)
        #expect(settings.timedPreset == .minimal)
        #expect(settings.timedAlerts.count == 1)

        // Reset defaults -> preset becomes standard with 2 alerts, resets reminder flags
        settings.allDayDayOf = false
        settings.alertSound = "Custom Sound"

        settings.resetReminderDefaults()

        #expect(settings.timedPreset == .standard)
        #expect(settings.timedAlerts.count == 2)
        #expect(settings.allDayDayOf == true)
        #expect(settings.allDayDayBefore == true)
        #expect(settings.routePrimary == .calendar)
        #expect(settings.alertSound == "Crystal Chime (Haptic Pulse)")

        // Apply standard to standard -> retains 2 alerts
        settings.applyTimedPreset(.standard)
        #expect(settings.timedPreset == .standard)
        #expect(settings.timedAlerts.count == 2)

        // Apply minimal again -> truncates to 1 alert
        settings.applyTimedPreset(.minimal)
        #expect(settings.timedPreset == .minimal)
        #expect(settings.timedAlerts.count == 1)
    }
}
