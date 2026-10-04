import Foundation
import Testing
@testable import DateSnap

@Suite("AppState Toast Tests")
@MainActor
struct AppStateToastTests {
    @Test("showToast sets toastMessage immediately")
    func showToastImmediate() {
        let appState = AppState()
        #expect(appState.toastMessage == nil)

        appState.showToast("Saved!")
        #expect(appState.toastMessage == "Saved!")
    }

    @Test("showToast clears toastMessage after 2.5s delay")
    func showToastAutoClear() async throws {
        let appState = AppState()

        appState.showToast("Event Created")
        #expect(appState.toastMessage == "Event Created")

        try await Task.sleep(nanoseconds: 2_700_000_000)
        #expect(appState.toastMessage == nil)
    }

    @Test("showToast overwrites previous message and does not clear newer message when first delay expires")
    func showToastOverwrite() async throws {
        let appState = AppState()

        appState.showToast("First Toast")
        #expect(appState.toastMessage == "First Toast")

        try await Task.sleep(nanoseconds: 500_000_000)
        appState.showToast("Second Toast")
        #expect(appState.toastMessage == "Second Toast")

        // Wait past the first toast's 2.5s expiration (total ~2.7s from start)
        try await Task.sleep(nanoseconds: 2_200_000_000)
        // First toast timer finished, but self.toastMessage ("Second Toast") != "First Toast", so message stays
        #expect(appState.toastMessage == "Second Toast")

        // Wait until second toast's timer expires (~3.3s total)
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(appState.toastMessage == nil)
    }
}
