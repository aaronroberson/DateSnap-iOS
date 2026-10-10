import Foundation
import Testing
@testable import DateSnap

@Suite("DateSnap Smoke Tests")
struct DateSnapSmokeTests {
    @Test("Smoke test initialization")
    func smokeTest() {
        #expect(true)
    }

    @Test("App display name uses the Pencil'd brand label")
    func testAppDisplayName() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Pencil'd")
    }

    @Test("Home uses the Pencil'd brand in safe copy")
    @MainActor
    func testHomeBrandCopy() {
        #expect(HomeBrandCopy.welcomeHeading == "Welcome to Pencil'd")
        #expect(HomeBrandCopy.scanDescription == "Take a screenshot of a flyer, text invite, or ticket, and Pencil'd will instantly turn it into a calendar event with custom reminders.")
        #expect(HomeBrandCopy.howItWorksHeading == "How Pencil'd Works")
        #expect(HomeBrandCopy.openAppTutorialTitle == "2. Open Pencil'd")
        #expect(HomeBrandCopy.photoLibraryPermissionMessage == "Pencil'd needs Photo Library access to find your recent screenshots. You can still pick individual photos without it.")
        #expect(HomeBrandCopy.premiumActiveToast == "Pencil'd Premium Active")
        #expect(HomeBrandCopy.premiumFileImportAccessibilityHint == "Requires Pencil'd Premium")
        #expect(HomeBrandCopy.plusScreenshotExplanation == "Pencil'd Plus checks new screenshots on your device and highlights likely events. Nothing is saved until you review it.")
    }

    @Test("DateSnapLinks URLs are valid")
    func testDateSnapLinks() {
        #expect(DateSnapLinks.support.absoluteString == "https://datesnap.app/support")
        #expect(DateSnapLinks.privacyPolicy.absoluteString == "https://datesnap.app/privacy")
        #expect(DateSnapLinks.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }
}
