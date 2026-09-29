import Foundation
import Testing
@testable import DateSnap

/// Exercises the real Foundation Models route when this machine can run it; otherwise verifies the fallback.
@Suite("Apple Intelligence live route")
struct AppleIntelligenceLiveTests {
    /// Opt-in (DATESNAP_EVAL_LIVE=1) because a real model pass takes 10–20 s.
    @Test("Live pipeline returns a validated result or a clean rules-only fallback",
          .enabled(if: ProcessInfo.processInfo.environment["DATESNAP_EVAL_LIVE"] == "1"))
    func livePipeline() async throws {
        let poster = makeOCR([
            ("SUMMER NIGHTS", 0.09),
            ("ROOFTOP SESSIONS", 0.088),
            ("October 17, 2026", 0.04),
            ("7:00 PM Lounge Opens", 0.04),
            ("8:30 PM Headliner Set", 0.04),
            ("The Skybar · 8440 Sunset Blvd", 0.03)
        ])
        let capability = IntelligenceComposition.currentCapability(locale: Locale(identifier: "en_US"))
        let result = await IntelligenceComposition.liveUnderstanding()
            .understand(poster, locale: Locale(identifier: "en_US"), anchor: testAnchor)
        let best = try #require(result.events.first?.best)
        print("capability=\(capability) route=\(result.route.rawValue) fallback=\(result.fallbackReason ?? "none") rejected=\(result.rejectedFieldCount)")
        print("title=\(best.title.value) [\(best.title.provenance.rawValue)] start=\(best.start.value) [\(best.start.provenance.rawValue)] category=\(best.category.rawValue)")
        if capability.isAvailable {
            // Whatever the model said, every accepted field must still be grounded in a real line.
            for ref in best.title.evidence + best.start.evidence {
                #expect(result.evidenceLine(ref.lineID) != nil)
            }
        } else {
            #expect(result.route == .rulesOnly)
        }
    }
}
