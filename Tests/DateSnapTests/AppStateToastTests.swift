import Foundation
import Testing
@testable import DateSnap

@MainActor
private final class ManualToastDismissalScheduler: ToastDismissalScheduling {
    private(set) var dismissals: [@MainActor @Sendable () -> Void] = []

    func scheduleDismissal(_ action: @escaping @MainActor @Sendable () -> Void) {
        dismissals.append(action)
    }

    func fireDismissal(at index: Int) {
        dismissals[index]()
    }
}

@Suite("AppState Toast Tests")
@MainActor
struct AppStateToastTests {
    @Test("showToast sets toastMessage immediately")
    func showToastImmediate() {
        let scheduler = ManualToastDismissalScheduler()
        let appState = AppState(toastDismissalScheduler: scheduler)
        #expect(appState.toastMessage == nil)

        appState.showToast("Saved!")
        #expect(appState.toastMessage == "Saved!")
        #expect(scheduler.dismissals.count == 1)
    }

    @Test("showToast clears toastMessage after 2.5s delay")
    func showToastAutoClear() {
        let scheduler = ManualToastDismissalScheduler()
        let appState = AppState(toastDismissalScheduler: scheduler)

        appState.showToast("Event Created")
        #expect(appState.toastMessage == "Event Created")

        scheduler.fireDismissal(at: 0)
        #expect(appState.toastMessage == nil)
    }

    @Test("showToast overwrites previous message and does not clear newer message when first delay expires")
    func showToastOverwrite() {
        let scheduler = ManualToastDismissalScheduler()
        let appState = AppState(toastDismissalScheduler: scheduler)

        appState.showToast("First Toast")
        #expect(appState.toastMessage == "First Toast")

        appState.showToast("Second Toast")
        #expect(appState.toastMessage == "Second Toast")

        scheduler.fireDismissal(at: 0)
        #expect(appState.toastMessage == "Second Toast")

        scheduler.fireDismissal(at: 1)
        #expect(appState.toastMessage == nil)
    }
}
