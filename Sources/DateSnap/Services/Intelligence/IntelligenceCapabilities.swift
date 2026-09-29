import Foundation

// MARK: - Runtime Capability

/// Why on-device semantic interpretation cannot run right now.
public enum IntelligenceUnavailableReason: String, Sendable, Codable, CaseIterable {
    /// The OS predates the Foundation Models API (iOS < 26).
    case osUnsupported
    /// The SDK the app was built with has no Foundation Models framework.
    case frameworkUnavailable
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case languageUnsupported
    case disabledByUser
    case disabledByRollout
    case unknown

    /// Plain-language explanation for Settings. Never implies the model ran.
    public var userFacingDescription: String {
        switch self {
        case .osUnsupported, .frameworkUnavailable:
            return "Needs iOS 26 or later. Scans use DateSnap's on-device rules."
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence. Scans use DateSnap's on-device rules."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in iOS Settings to enable enhanced interpretation."
        case .modelNotReady:
            return "Apple Intelligence is still getting ready. Scans use DateSnap's on-device rules for now."
        case .languageUnsupported:
            return "Enhanced interpretation isn't available in your language yet."
        case .disabledByUser:
            return "Enhanced interpretation is turned off."
        case .disabledByRollout:
            return "Enhanced interpretation isn't enabled in this build."
        case .unknown:
            return "Enhanced interpretation is unavailable right now."
        }
    }
}

public enum IntelligenceCapability: Sendable, Equatable {
    case available
    case unavailable(IntelligenceUnavailableReason)

    public var isAvailable: Bool { self == .available }
}

/// Reports whether the on-device model can run *now*. Query at use time: availability depends on OS,
/// device, language, model readiness and the user's Apple Intelligence setting, not hardware alone.
public protocol IntelligenceCapabilityProviding: Sendable {
    func currentCapability(for locale: Locale) -> IntelligenceCapability
}

/// Always unavailable. Used on older OS versions, in previews and in tests.
public struct UnavailableCapabilityProvider: IntelligenceCapabilityProviding {
    public let reason: IntelligenceUnavailableReason

    public init(reason: IntelligenceUnavailableReason = .osUnsupported) {
        self.reason = reason
    }

    public func currentCapability(for locale: Locale) -> IntelligenceCapability {
        .unavailable(reason)
    }
}

/// Always available. Used with a scripted interpreter in tests.
public struct AvailableCapabilityProvider: IntelligenceCapabilityProviding {
    public init() {}
    public func currentCapability(for locale: Locale) -> IntelligenceCapability { .available }
}
