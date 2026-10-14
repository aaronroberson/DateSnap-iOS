import Foundation
import Testing
@testable import Pencild

@Suite("Apple account link")
struct AppleAccountTests {
    @Test("Sign-out clears the stored Apple ID details and the signed-in state")
    func signOutClears() throws {
        let defaults = try #require(UserDefaults(suiteName: "pencild.tests.apple.\(UUID().uuidString)"))
        #expect(!AppleAccount.isSignedIn(defaults: defaults))
        defaults.set("001234.abcd", forKey: AppleAccount.userIDKey)
        defaults.set("Ada Lovelace", forKey: AppleAccount.displayNameKey)
        defaults.set("ada@example.com", forKey: AppleAccount.emailKey)
        #expect(AppleAccount.isSignedIn(defaults: defaults))

        AppleAccount.signOut(defaults: defaults)

        #expect(!AppleAccount.isSignedIn(defaults: defaults))
        #expect(defaults.string(forKey: AppleAccount.displayNameKey) == nil)
        #expect(defaults.string(forKey: AppleAccount.emailKey) == nil)
    }
}
