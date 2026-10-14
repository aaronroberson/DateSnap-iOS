import Foundation
import Testing
@testable import Pencild

@Suite("Reminder defaults store")
struct ReminderDefaultsStoreTests {
    private func store() -> ReminderDefaultsStore {
        ReminderDefaultsStore(defaultsSuiteName: "pencild.tests.reminderDefaults.\(UUID().uuidString)")
    }

    @Test("Unset store keeps the Standard alerts new events have always had")
    func unsetIsStandard() {
        let store = store()
        #expect(store.preset() == .defaultPreset)
        #expect(store.defaultOffsets() == ReminderOffset.defaultStaggered)
    }

    @Test("A chosen preset round-trips and drives the default alerts")
    func roundTrip() {
        let store = store()
        store.setPreset(.travelHeavy)
        #expect(store.preset() == .travelHeavy)
        #expect(store.defaultOffsets() == ReminderPreset.travelHeavy.offsets)

        store.setPreset(.dayOfOnly)
        #expect(store.defaultOffsets() == [.twoHoursBefore])
    }

    @Test("Custom is not a default choice and is ignored")
    func customIgnored() {
        let store = store()
        store.setPreset(.dayOfOnly)
        store.setPreset(.custom)
        #expect(store.preset() == .dayOfOnly)
    }

    @Test("Every default choice has at most three alerts")
    func presetsWithinLimit() {
        for preset in ReminderPreset.defaultChoices {
            #expect((preset.offsets?.count ?? 0) <= PlanLimits.paidAlertsPerEvent)
            #expect(preset.offsets?.isEmpty == false)
        }
    }
}
