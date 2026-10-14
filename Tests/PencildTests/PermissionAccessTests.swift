import EventKit
import Photos
import Testing
import UserNotifications
@testable import Pencild

@Suite("Permission access")
struct PermissionAccessTests {
    @Test("Limited Photos and add-only Calendar are partial but usable")
    func partialIsUsable() {
        #expect(PHAuthorizationStatus.limited.access == .partial)
        #expect(PHAuthorizationStatus.limited.access.isUsable)
        #expect(EKAuthorizationStatus.writeOnly.access == .partial)
        #expect(EKAuthorizationStatus.writeOnly.access.isUsable)
        #expect(!EKAuthorizationStatus.writeOnly.canReadCalendars)
        #expect(EKAuthorizationStatus.fullAccess.canReadCalendars)
    }

    @Test("Provisional and ephemeral notifications count as on everywhere")
    func notifications() {
        #expect(UNAuthorizationStatus.provisional.access.isUsable)
        #expect(UNAuthorizationStatus.ephemeral.access.isUsable)
        #expect(UNAuthorizationStatus.denied.access == .denied)
        #expect(UNAuthorizationStatus.notDetermined.access == .notAsked)
    }

    @Test("Settings labels follow the shared reading")
    func labels() {
        #expect(PHAuthorizationStatus.limited.settingsLabel == "Limited")
        #expect(EKAuthorizationStatus.writeOnly.settingsLabel == "Add Only")
        #expect(EKAuthorizationStatus.denied.settingsLabel == "Off")
        #expect(UNAuthorizationStatus.ephemeral.settingsLabel == "On")
        #expect(PHAuthorizationStatus.notDetermined.settingsLabel == "Not Asked")
    }
}
