import Foundation

// MARK: - Intelligence Policy
/// Central decision on whether the on-device semantic pass runs for a scan: user setting, rollout flag,
/// runtime capability, scan quality and whether the deterministic result actually needs help.
/// Subscription tier is deliberately *not* an input — single-scan interpretation is a review-quality feature.
public struct IntelligencePolicy: Sendable {
    public static let userDefaultsKey = "intelligence.enhancedInterpretationEnabled"
    public static let rolloutInfoKey = "DSEnhancedInterpretationRollout"

    public var userEnabled: Bool
    public var rolloutEnabled: Bool
    /// Upper bound on OCR lines sent to the model.
    public var maxInputLines: Int
    /// Upper bound on characters sent to the model.
    public var maxInputCharacters: Int
    /// A slow model pass is abandoned after this long and the baseline is returned.
    public var timeout: Duration

    public init(
        userEnabled: Bool = true,
        rolloutEnabled: Bool = true,
        maxInputLines: Int = 60,
        maxInputCharacters: Int = 3000,
        timeout: Duration = .seconds(12)
    ) {
        self.userEnabled = userEnabled
        self.rolloutEnabled = rolloutEnabled
        self.maxInputLines = maxInputLines
        self.maxInputCharacters = maxInputCharacters
        self.timeout = timeout
    }

    /// Reads the user toggle (default on) and the build's rollout flag (default on).
    public static func current(defaults: UserDefaults = .standard, bundle: Bundle = .main) -> IntelligencePolicy {
        let userEnabled = defaults.object(forKey: userDefaultsKey) as? Bool ?? true
        let rolloutEnabled = bundle.object(forInfoDictionaryKey: rolloutInfoKey) as? Bool ?? true
        return IntelligencePolicy(userEnabled: userEnabled, rolloutEnabled: rolloutEnabled)
    }

    public enum Decision: Equatable, Sendable {
        case interpret(reasons: [String])
        case skip(reason: String)
    }

    /// Decides whether to invoke the model. `triggers` are the deterministic reasons the scan could
    /// benefit (ambiguity, unlabeled time pairs, low title margin, deadlines…); none means skip.
    public func decide(capability: IntelligenceCapability, quality: OCRQualityReport, triggers: [String]) -> Decision {
        guard rolloutEnabled else { return .skip(reason: IntelligenceUnavailableReason.disabledByRollout.rawValue) }
        guard userEnabled else { return .skip(reason: IntelligenceUnavailableReason.disabledByUser.rawValue) }
        if case .unavailable(let reason) = capability {
            return .skip(reason: reason.rawValue)
        }
        guard quality.lineCount > 0, quality.isScanWorthy else { return .skip(reason: "notScanWorthy") }
        guard !triggers.isEmpty else { return .skip(reason: "baselineClear") }
        return .interpret(reasons: triggers)
    }
}
