import Foundation
import SwiftUI
import Testing
@testable import DateSnap

@Suite("AppState Image State Tests")
@MainActor
struct AppStateImageStateTests {

    @Test("clearSourceImages clears sourceImages dictionary and resets lastScanImage to nil")
    func clearSourceImagesWhenPopulated() {
        let appState = AppState()
        let testImage = UIImage()
        let candidate1 = EventCandidate(title: "Concert", startDate: testAnchor)
        let candidate2 = EventCandidate(title: "Art Exhibit", startDate: testAnchor)

        appState.lastScanImage = testImage
        appState.rememberSourceImage(testImage, for: [candidate1, candidate2])

        #expect(appState.lastScanImage != nil)
        #expect(appState.sourceImages.count == 2)
        #expect(appState.sourceImages[candidate1.id] != nil)
        #expect(appState.sourceImages[candidate2.id] != nil)

        appState.clearSourceImages()

        #expect(appState.sourceImages.isEmpty)
        #expect(appState.lastScanImage == nil)
    }

    @Test("clearSourceImages maintains empty state when called on an unpopulated AppState")
    func clearSourceImagesWhenAlreadyEmpty() {
        let appState = AppState()

        #expect(appState.sourceImages.isEmpty)
        #expect(appState.lastScanImage == nil)

        appState.clearSourceImages()

        #expect(appState.sourceImages.isEmpty)
        #expect(appState.lastScanImage == nil)
    }
}
