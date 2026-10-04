import Foundation
import Testing
@testable import DateSnap

/// Deterministic stand-in for the Foundation Models interpreter.
struct ScriptedInterpreter: OnDeviceEventInterpreting {
    enum Script: Sendable {
        case hypotheses([EventHypothesis])
        case failure
        case delay(Duration)
    }
    let script: Script

    struct Failure: Error {}

    func interpret(_ request: InterpretationRequest) async throws -> [EventHypothesis] {
        switch script {
        case .hypotheses(let result): return result
        case .failure: throw Failure()
        case .delay(let duration):
            try await Task.sleep(for: duration)
            return []
        }
    }
}

@Suite("Event understanding pipeline routing and fallback")
struct EventUnderstandingPipelineTests {
    /// Unlabeled time pair plus two prominent lines: triggers the semantic pass.
    let poster = makeOCR([
        ("SUMMER NIGHTS", 0.09),
        ("ROOFTOP SESSIONS", 0.088),
        ("October 17, 2026", 0.04),
        ("7:00 PM Lounge Opens", 0.04),
        ("8:30 PM Headliner Set", 0.04)
    ])

    func pipeline(_ script: ScriptedInterpreter.Script, userEnabled: Bool = true, timeout: Duration = .seconds(2)) -> EventUnderstandingPipeline {
        EventUnderstandingPipeline(
            capability: AvailableCapabilityProvider(),
            makeInterpreter: { ScriptedInterpreter(script: script) },
            policy: { IntelligencePolicy(userEnabled: userEnabled, timeout: timeout) }
        )
    }

    func understand(_ pipeline: EventUnderstandingPipeline) async -> EventUnderstandingResult {
        await pipeline.understand(poster, locale: Locale(identifier: "en_US"), anchor: testAnchor)
    }

    @Test("Rules-only pipeline returns the deterministic interpretation")
    func rulesOnly() async throws {
        let result = await EventUnderstandingPipeline.rulesOnly().understand(poster, locale: Locale(identifier: "en_US"), anchor: testAnchor)
        #expect(result.route == .rulesOnly)
        #expect(result.fallbackReason == IntelligenceUnavailableReason.osUnsupported.rawValue)
        let best = try #require(result.events.first?.best)
        #expect(best.start.provenance != .modelInterpretation)
        #expect(result.quality.isScanWorthy)
    }

    @Test("Valid model output is merged and marked on-device")
    func validModelOutput() async throws {
        let hypothesis = EventHypothesis(titleLineID: 0, titleText: "Summer Nights", dateLineID: 2,
                                         startTimeLineID: 4, startTimeText: "8:30 PM",
                                         doorsTimeLineID: 3, doorsTimeText: "7:00 PM", category: "concert")
        let result = await understand(pipeline(.hypotheses([hypothesis])))
        #expect(result.route == .onDeviceModel)
        let best = try #require(result.events.first?.best)
        #expect(best.start.provenance == .modelInterpretation)
        #expect(testCalendar.component(.hour, from: best.start.value) == 20)
        #expect(best.doorsTime != nil)
    }

    @Test("Interpreter errors, timeouts and fully rejected output fall back to rules")
    func fallbacks() async throws {
        let failed = await understand(pipeline(.failure))
        #expect(failed.route == .rulesOnly)
        #expect(failed.fallbackReason == "modelError")
        #expect(!failed.events.isEmpty)

        let slow = await understand(pipeline(.delay(.seconds(5)), timeout: .milliseconds(100)))
        #expect(slow.route == .rulesOnly)
        #expect(slow.fallbackReason == "timeout")
        #expect(!slow.events.isEmpty)

        let invented = EventHypothesis(titleLineID: 42, titleText: "Invented", startTimeLineID: 4, startTimeText: "11:59 PM")
        let rejected = await understand(pipeline(.hypotheses([invented])))
        #expect(rejected.route == .rulesOnly)
        #expect(rejected.fallbackReason == "allOutputRejected")
        #expect(rejected.rejectedFieldCount >= 2)
    }

    @Test("The user toggle skips the model entirely")
    func userDisabled() async {
        let result = await understand(pipeline(.failure, userEnabled: false))
        #expect(result.route == .rulesOnly)
        #expect(result.fallbackReason == IntelligenceUnavailableReason.disabledByUser.rawValue)
    }

    @Test("Clear scans skip the model even when available")
    func clearScanSkips() async {
        let clear = makeOCR([("Book Club", 0.08), ("October 20, 2026 at 7pm", 0.04), ("Central Library", 0.03)])
        let result = await pipeline(.failure).understand(clear, locale: Locale(identifier: "en_US"), anchor: testAnchor)
        #expect(result.fallbackReason == "baselineClear")
    }

    @Test("Interpretation candidates materialize into the canonical value snapshot")
    func materialization() async throws {
        let result = await EventUnderstandingPipeline.rulesOnly().understand(poster, locale: Locale(identifier: "en_US"), anchor: testAnchor)
        let best = try #require(result.events.first?.best)
        let data = best.toExtractedData()
        #expect(data.id == best.id)
        #expect(data.title == best.title.value)
        #expect(data.startDate == best.start.value)
    }
}
