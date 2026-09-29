import Foundation

// MARK: - Intelligence Composition
/// Chooses the live understanding pipeline for this OS/SDK. Runtime availability is still checked per scan.
enum IntelligenceComposition {
    static func liveUnderstanding() -> EventUnderstandingProviding {
        EventUnderstandingPipeline.rulesOnly(reason: .frameworkUnavailable)
    }
}
