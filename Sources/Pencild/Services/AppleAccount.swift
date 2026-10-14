import AuthenticationServices
import Foundation

// MARK: - Apple Account
/// The optional Sign in with Apple link, stored on this device. Pencil’d has no server account:
/// signing in only shows the Apple ID name and email in Profile. Used by Profile and the splash.
enum AppleAccount {
    static let userIDKey = "account.appleUserID"
    static let displayNameKey = "account.displayName"
    static let emailKey = "account.email"
    static let linkedAtKey = "account.linkedAt"
    /// The splash offers sign-in until the person signs in or chooses to continue without one.
    static let splashChoiceKey = "account.splashSignInChoiceMade"

    /// Off in Release until the organization team has the Sign in with Apple entitlement
    /// (release checklist); without it sign-in fails on device.
    static var isSignInAvailable: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func isSignedIn(defaults: UserDefaults = .standard) -> Bool {
        !(defaults.string(forKey: userIDKey) ?? "").isEmpty
    }

    /// Stores the credential. Apple returns name and email only on the first authorization, so
    /// existing values are kept when they're missing.
    static func store(_ credential: ASAuthorizationAppleIDCredential, defaults: UserDefaults = .standard) {
        defaults.set(credential.user, forKey: userIDKey)
        defaults.set(Date().timeIntervalSince1970, forKey: linkedAtKey)
        if let components = credential.fullName {
            let formatted = PersonNameComponentsFormatter().string(from: components)
            if !formatted.isEmpty { defaults.set(formatted, forKey: displayNameKey) }
        }
        if let email = credential.email, !email.isEmpty {
            defaults.set(email, forKey: emailKey)
        }
    }

    /// Handles a Sign in with Apple result. Returns an error message to show, or nil (success or
    /// cancellation).
    static func handle(_ result: Result<ASAuthorization, Error>, defaults: UserDefaults = .standard) -> String? {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
            store(credential, defaults: defaults)
            return nil
        case .failure(let error):
            return (error as? ASAuthorizationError)?.code == .canceled ? nil : "Sign in with Apple didn’t complete"
        }
    }

    static func signOut(defaults: UserDefaults = .standard) {
        for key in [userIDKey, displayNameKey, emailKey, linkedAtKey] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Drops the link if the person revoked Pencil’d in their Apple ID settings.
    static func validate(defaults: UserDefaults = .standard) async {
        guard let userID = defaults.string(forKey: userIDKey), !userID.isEmpty else { return }
        let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
        if state == .revoked || state == .notFound { signOut(defaults: defaults) }
    }
}
