import Testing
@testable import DateSnap

@Suite("DateSnap Smoke Tests")
struct DateSnapSmokeTests {
    @Test("Smoke test initialization")
    func smokeTest() {
        #expect(true)
    }

    @Test("DateSnapLinks URLs are valid")
    func testDateSnapLinks() {
        #expect(DateSnapLinks.support.absoluteString == "https://datesnap.app/support")
        #expect(DateSnapLinks.privacyPolicy.absoluteString == "https://datesnap.app/privacy")
        #expect(DateSnapLinks.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }
}
