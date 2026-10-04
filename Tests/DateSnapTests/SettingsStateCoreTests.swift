import Foundation
import Testing
@testable import DateSnap

@MainActor
@Suite("SettingsState Core Tests")
struct SettingsStateCoreTests {

    @Test("Default state initial values")
    func testDefaultValues() {
        let state = SettingsState()

        // Plan / Billing
        #expect(state.isAnnual == true)
        #expect(state.autoRenewal == true)

        // Privacy & Security
        #expect(state.screenshotAutoPurge == true)
        #expect(state.faceIDProtection == true)
        #expect(state.purgeWindow == .immediate)

        // Scanning & Capture
        #expect(state.scanProfile == .review)
        #expect(state.captureScopeCameraPhotos == false)
        #expect(state.includeAirDropShared == true)
        #expect(state.confidence == 85)
        #expect(state.draftLowConfidence == true)

        // Digest & Notifications
        #expect(state.quickExtractionPrompt == true)
        #expect(state.eveningDigest == true)
        #expect(state.pauseOnLowPower == true)

        // Reminder Defaults
        #expect(state.timedPreset == .thorough)
        #expect(state.timedAlerts.count == 3)
        #expect(state.allDayDayOf == true)
        #expect(state.allDayDayBefore == true)
        #expect(state.routePrimary == .calendar)
        #expect(state.alertSound == "Crystal Chime (Haptic Pulse)")
        #expect(state.pendingRoute == nil)
    }

    @Test("Computed properties planName and planPrice")
    func testPlanComputedProperties() {
        let state = SettingsState()

        // Annual plan (default)
        state.isAnnual = true
        #expect(state.planName == "DateSnap Plus (Annual)")
        #expect(state.planPrice == "$29.99")

        // Monthly plan
        state.isAnnual = false
        #expect(state.planName == "DateSnap Plus (Monthly)")
        #expect(state.planPrice == "$4.99")
    }

    @Test("PurgeWindow enum metadata and rawValues")
    func testPurgeWindowMetadata() {
        #expect(SettingsState.PurgeWindow.immediate.rawValue == "Immediate")
        #expect(SettingsState.PurgeWindow.sevenDays.rawValue == "After 7 days")
        #expect(SettingsState.PurgeWindow.thirtyDays.rawValue == "After 30 days")
        #expect(SettingsState.PurgeWindow.manual.rawValue == "Manual only")

        for window in SettingsState.PurgeWindow.allCases {
            #expect(window.id == window.rawValue)
        }
    }

    @Test("ScanProfile enum metadata and properties")
    func testScanProfileMetadata() {
        #expect(SettingsState.ScanProfile.review.rawValue == "Review Mode")
        #expect(SettingsState.ScanProfile.review.badge == "Recommended")
        #expect(SettingsState.ScanProfile.review.subtitle == "Safe AI Automation")
        #expect(SettingsState.ScanProfile.review.icon == "rule.fill")
        #expect(!SettingsState.ScanProfile.review.blurb.isEmpty)

        #expect(SettingsState.ScanProfile.smartSave.rawValue == "Smart Save Mode")
        #expect(SettingsState.ScanProfile.smartSave.badge == "Experimental")
        #expect(SettingsState.ScanProfile.smartSave.subtitle == "High Velocity")
        #expect(SettingsState.ScanProfile.smartSave.icon == "auto.fix.high")
        #expect(!SettingsState.ScanProfile.smartSave.blurb.isEmpty)

        #expect(SettingsState.ScanProfile.manual.rawValue == "Manual Only")
        #expect(SettingsState.ScanProfile.manual.badge == "Zero Activity")
        #expect(SettingsState.ScanProfile.manual.subtitle == "Zero Background Activity")
        #expect(SettingsState.ScanProfile.manual.icon == "hand.tap.fill")
        #expect(!SettingsState.ScanProfile.manual.blurb.isEmpty)

        for profile in SettingsState.ScanProfile.allCases {
            #expect(profile.id == profile.rawValue)
        }
    }

    @Test("TimedPreset enum metadata and properties")
    func testTimedPresetMetadata() {
        #expect(SettingsState.TimedPreset.thorough.rawValue == "Thorough")
        #expect(SettingsState.TimedPreset.thorough.alertCount == 3)
        #expect(SettingsState.TimedPreset.thorough.caption == "3 alerts")

        #expect(SettingsState.TimedPreset.standard.rawValue == "Standard")
        #expect(SettingsState.TimedPreset.standard.alertCount == 2)
        #expect(SettingsState.TimedPreset.standard.caption == "2 alerts")

        #expect(SettingsState.TimedPreset.minimal.rawValue == "Minimal")
        #expect(SettingsState.TimedPreset.minimal.alertCount == 1)
        #expect(SettingsState.TimedPreset.minimal.caption == "1 alert")

        for preset in SettingsState.TimedPreset.allCases {
            #expect(preset.id == preset.rawValue)
        }
    }

    @Test("DeliveryRoute enum metadata and properties")
    func testDeliveryRouteMetadata() {
        #expect(SettingsState.DeliveryRoute.calendar.rawValue == "Calendar")
        #expect(SettingsState.DeliveryRoute.calendar.subtitle == "Primary")
        #expect(SettingsState.DeliveryRoute.calendar.icon == "calendar")

        #expect(SettingsState.DeliveryRoute.reminders.rawValue == "Reminders")
        #expect(SettingsState.DeliveryRoute.reminders.subtitle == "Actionable")
        #expect(SettingsState.DeliveryRoute.reminders.icon == "checklist")

        #expect(SettingsState.DeliveryRoute.push.rawValue == "DateSnap")
        #expect(SettingsState.DeliveryRoute.push.subtitle == "Push Ping")
        #expect(SettingsState.DeliveryRoute.push.icon == "notifications")

        for route in SettingsState.DeliveryRoute.allCases {
            #expect(route.id == route.rawValue)
        }
    }

    @Test("Light smoke check for applyTimedPreset mutation")
    func testApplyTimedPresetSmokeCheck() {
        let state = SettingsState()
        #expect(state.timedPreset == .thorough)
        #expect(state.timedAlerts.count == 3)

        state.applyTimedPreset(.standard)
        #expect(state.timedPreset == .standard)
        #expect(state.timedAlerts.count == 2)
    }

    @Test("Light smoke check for resetReminderDefaults mutation")
    func testResetReminderDefaultsSmokeCheck() {
        let state = SettingsState()
        state.timedPreset = .minimal
        state.timedAlerts = []
        state.alertSound = "Custom"

        state.resetReminderDefaults()
        #expect(state.timedPreset == .standard)
        #expect(state.timedAlerts.count == 2)
        #expect(state.alertSound == "Crystal Chime (Haptic Pulse)")
    }
}
