import Combine
import Foundation
import Testing
@testable import Pencild

@Suite("AppState navigation")
@MainActor
struct AppStateNavigationTests {
    /// Records every `activeModal` value the root sheet binding would observe, `nil` included.
    private func recordModals(of appState: AppState) -> (log: () -> [String?], token: AnyCancellable) {
        var values: [String?] = []
        let token = appState.$activeModal.dropFirst().sink { values.append($0?.id) }
        return ({ values }, token)
    }

    @Test("present shows the modal immediately when no sheet is on screen")
    func presentWithoutSheet() async {
        let appState = AppState()
        let (log, token) = recordModals(of: appState)

        await appState.present(.plusPaywall)

        #expect(log() == [AppModalScreen.plusPaywall.id])
        withExtendedLifetime(token) {}
    }

    @Test("present dismisses the current sheet before showing the next one")
    func presentReplacesSheet() async {
        let appState = AppState()
        await appState.present(.recentScreenshots)
        let (log, token) = recordModals(of: appState)

        await appState.present(.premiumPaywall)

        #expect(log() == [nil, AppModalScreen.premiumPaywall.id])
        withExtendedLifetime(token) {}
    }

    @Test("Batch review replaces a modal sheet, and a later modal leaves the batch session intact")
    func batchReviewAndModalCoexist() async {
        let appState = AppState()
        await appState.present(.recentScreenshots)
        let session = BatchReviewSession(events: [])

        await appState.presentBatchReview(session)
        #expect(appState.activeModal == nil)
        #expect(appState.batchReviewSession === session)

        // Unsaved batch edits must survive a modal request made while the batch is on screen.
        await appState.present(.plusPaywall)
        #expect(appState.batchReviewSession === session)
    }

    @Test("An already-saved scan closes the sheet and opens History under Agenda")
    func alreadySavedOutcomeOpensHistory() async {
        let appState = AppState()
        await appState.present(.recentScreenshots)
        // Only the stage is read when routing; no scan runs.
        let scan = ScanViewModel(services: ServiceContainer.live())
        scan.stage = .alreadySaved(count: 2)

        await appState.handleScanOutcome(scan)

        #expect(appState.activeModal == nil)
        #expect(appState.selectedTab == .agenda)
        #expect(appState.showHistory)
        #expect(appState.toastMessage == "All 2 events are already saved")
    }

    @Test("No-dates scan presents the recovery screen with the scanned text")
    func noDatesOutcomePresentsRecovery() async {
        let appState = AppState()
        let scan = ScanViewModel(services: ServiceContainer.live())
        scan.stage = .noDatesFound(rawText: "Garage sale this weekend")

        await appState.handleScanOutcome(scan)

        #expect(appState.activeModal?.id == AppModalScreen.noDatesFound.id)
        #expect(appState.lastScanRawText == "Garage sale this weekend")
    }

    @Test("Settings deep links are typed routes consumed by the Settings stack")
    func settingsRouteIsTyped() {
        let settings = SettingsState()
        settings.pendingRoute = .managePlan
        #expect(settings.pendingRoute == .managePlan)
    }
}
