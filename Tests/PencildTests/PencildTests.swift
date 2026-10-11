import Foundation
import Testing
@testable import Pencild

@Suite("Pencild Smoke Tests")
struct PencildSmokeTests {
    @Test("Smoke test initialization")
    func smokeTest() {
        #expect(true)
    }

    @Test("App display name uses the Pencil'd brand label")
    func testAppDisplayName() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Pencil'd")
        #expect(SubscriptionTier.starter.rawValue == "Starter")
        #expect(SubscriptionTier.plus.rawValue == "Plus")
        #expect(SubscriptionTier.premium.rawValue == "Premium")
        #expect(SubscriptionTier.starter.displayName == "Pencil'd Free")
        #expect(SubscriptionTier.plus.displayName == "Pencil'd Plus")
        #expect(SubscriptionTier.premium.displayName == "Pencil'd Premium")
        #expect(SubscriptionTier.starter.badgeText == "FREE")
        #expect(SubscriptionTier.plus.badgeText == "PLUS")
        #expect(SubscriptionTier.premium.badgeText == "PREMIUM")
    }

    @Test("Home uses the Pencil'd brand in safe copy")
    @MainActor
    func testHomeBrandCopy() {
        #expect(HomeBrandCopy.captureHeading == "Turn Schedules Into Events")
        #expect(HomeBrandCopy.captureSubtitle == "Scan flyers, import syllabi, or let Pencil'd Plus spot events in your new screenshots.")
        #expect(HomeBrandCopy.photoLibraryPermissionMessage == "Pencil'd needs Photo Library access to find your recent screenshots. You can still pick individual photos without it.")
        #expect(HomeBrandCopy.premiumFileImportAccessibilityHint == "Requires Pencil'd Premium")
        #expect(HomeBrandCopy.plusScreenshotExplanation == "Pencil'd Plus checks new screenshots on your device and highlights likely events. Nothing is saved until you review it.")
    }

    @Test("PencildLinks URLs are valid")
    func testPencildLinks() {
        #expect(PencildLinks.support.absoluteString == "https://pencild.app/support")
        #expect(PencildLinks.privacyPolicy.absoluteString == "https://pencild.app/privacy")
        #expect(PencildLinks.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
        #expect(PencildLinks.support == PencildLinks.support)
    }
}
