import Foundation

// MARK: - Intelligence Composition
/// Chooses the live understanding pipeline for this OS/SDK. Runtime availability is still checked per scan,
/// and the interpreter is only constructed when a scan actually routes to it.
enum IntelligenceComposition {
    static func liveUnderstanding() -> EventUnderstandingProviding {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return EventUnderstandingPipeline(
                capability: AppleIntelligenceCapabilityProvider(),
                makeInterpreter: { AppleFoundationModelInterpreter() }
            )
        }
        return EventUnderstandingPipeline.rulesOnly(reason: .osUnsupported)
        #else
        return EventUnderstandingPipeline.rulesOnly(reason: .frameworkUnavailable)
        #endif
    }

    /// Current capability for display in Settings (never implies the model ran).
    static func currentCapability(locale: Locale = .current) -> IntelligenceCapability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return AppleIntelligenceCapabilityProvider().currentCapability(for: locale)
        }
        return .unavailable(.osUnsupported)
        #else
        return .unavailable(.frameworkUnavailable)
        #endif
    }
}
