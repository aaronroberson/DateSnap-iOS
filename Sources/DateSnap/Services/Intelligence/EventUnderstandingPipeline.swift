import Foundation
import os

// MARK: - Event Understanding Pipeline

/// Produces an `EventUnderstandingResult` from OCR. Implementations must always return a usable result:
/// any model unavailability, timeout, failure or invalid output falls back to the deterministic baseline.
public protocol EventUnderstandingProviding: Sendable {
    func analyze(_ result: OCRResult, locale: Locale, anchor: Date, assetIdentifier: String) async -> PreparedUnderstanding
    func complete(_ prepared: PreparedUnderstanding) async -> EventUnderstandingResult
}

extension EventUnderstandingProviding {
    public func understand(_ result: OCRResult, locale: Locale = .current, anchor: Date = Date(), assetIdentifier: String = "local_asset") async -> EventUnderstandingResult {
        await complete(await analyze(result, locale: locale, anchor: anchor, assetIdentifier: assetIdentifier))
    }
}

/// Deterministic analysis plus the routing decision, returned before any model work so the UI can
/// show "Interpreting event details on device" only when the model will actually run.
public struct PreparedUnderstanding: Sendable {
    public var analysis: RuleBasedEventAnalyzer.Analysis
    public var decision: IntelligencePolicy.Decision
    public var locale: Locale
    public var anchor: Date
    public var policy: IntelligencePolicy

    public var willInterpret: Bool {
        if case .interpret = decision { return true }
        return false
    }
}

/// Deterministic extraction → policy gate → optional on-device interpretation → validation → ranking.
public struct EventUnderstandingPipeline: EventUnderstandingProviding {
    private let capability: IntelligenceCapabilityProviding
    /// Created lazily per scan so unsupported devices never initialize model state.
    private let makeInterpreter: @Sendable () -> OnDeviceEventInterpreting?
    private let policy: @Sendable () -> IntelligencePolicy

    public init(
        capability: IntelligenceCapabilityProviding,
        makeInterpreter: @escaping @Sendable () -> OnDeviceEventInterpreting?,
        policy: @escaping @Sendable () -> IntelligencePolicy = { IntelligencePolicy.current() }
    ) {
        self.capability = capability
        self.makeInterpreter = makeInterpreter
        self.policy = policy
    }

    /// Rules-only pipeline (older OS, previews, tests).
    public static func rulesOnly(reason: IntelligenceUnavailableReason = .osUnsupported) -> EventUnderstandingPipeline {
        EventUnderstandingPipeline(capability: UnavailableCapabilityProvider(reason: reason), makeInterpreter: { nil })
    }

    public func analyze(_ result: OCRResult, locale: Locale, anchor: Date, assetIdentifier: String) async -> PreparedUnderstanding {
        let span = IntelligenceTelemetry.begin("analyze")
        let analysis = await Task.detached(priority: .userInitiated) {
            let extracted = EventExtractionCore.extract(from: result, locale: locale, anchor: anchor, assetIdentifier: assetIdentifier)
            return RuleBasedEventAnalyzer.analyze(result: result, extracted: extracted, locale: locale, anchor: anchor)
        }.value
        let currentPolicy = policy()
        let decision: IntelligencePolicy.Decision = analysis.events.isEmpty
            ? .skip(reason: "noCandidates")
            : currentPolicy.decide(capability: capability.currentCapability(for: locale), quality: analysis.quality, triggers: analysis.triggers)
        IntelligenceTelemetry.end(span, "analyze", detail: "events=\(analysis.events.count) triggers=\(analysis.triggers.count)")
        return PreparedUnderstanding(analysis: analysis, decision: decision, locale: locale, anchor: anchor, policy: currentPolicy)
    }

    public func complete(_ prepared: PreparedUnderstanding) async -> EventUnderstandingResult {
        let analysis = prepared.analysis
        var hypotheses: [EventHypothesis] = []
        var route = EngineRoute.rulesOnly
        var fallbackReason: String? = nil

        switch prepared.decision {
        case .skip(let reason):
            fallbackReason = reason
        case .interpret:
            if let interpreter = makeInterpreter() {
                let span = IntelligenceTelemetry.begin("interpret")
                let request = InterpretationRequest(
                    lines: analysis.evidence,
                    referenceDate: prepared.anchor,
                    localeIdentifier: prepared.locale.identifier,
                    timeZoneIdentifier: TimeZone.current.identifier,
                    baseline: analysis.events.map(\.best),
                    triggers: analysis.triggers
                ).bounded(by: prepared.policy)
                do {
                    hypotheses = try await Self.withTimeout(prepared.policy.timeout) {
                        try await interpreter.interpret(request)
                    }
                    route = .onDeviceModel
                    IntelligenceTelemetry.end(span, "interpret", detail: "hypotheses=\(hypotheses.count)")
                } catch is CancellationError {
                    fallbackReason = "cancelled"
                    IntelligenceTelemetry.end(span, "interpret", detail: "fallback=cancelled")
                } catch {
                    fallbackReason = (error as? PipelineError)?.rawValue ?? "modelError"
                    IntelligenceTelemetry.end(span, "interpret", detail: "fallback=\(fallbackReason ?? "")")
                }
            } else {
                fallbackReason = IntelligenceUnavailableReason.frameworkUnavailable.rawValue
            }
        }

        var rejected = 0
        var acceptedAny = false
        let events = analysis.events.enumerated().map { index, event -> EventUnderstanding in
            let baseline = event.best
            var modelCandidate: EventInterpretationCandidate? = nil
            if index < hypotheses.count {
                let outcome = EvidenceValidator.validate(hypotheses[index], against: baseline, evidence: analysis.evidence,
                                                         locale: prepared.locale, anchor: prepared.anchor)
                rejected += outcome.rejectedFields.count
                modelCandidate = outcome.candidate
                acceptedAny = acceptedAny || outcome.candidate != nil
            }
            let alternatives = InterpretationRanker.deterministicAlternatives(for: baseline, titleCandidates: analysis.titleCandidates)
            let ranked = InterpretationRanker.rank(baseline: baseline, modelCandidate: modelCandidate,
                                                   deterministicAlternatives: alternatives,
                                                   ocrMeanConfidence: analysis.quality.meanConfidence)
            var understanding = event
            understanding.best = ranked.best
            understanding.alternatives = ranked.alternatives
            understanding.questions = InterpretationRanker.questions(best: ranked.best, alternatives: ranked.alternatives)
            return understanding
        }

        // The model ran but nothing it said survived validation: this is a rules-only result.
        if route == .onDeviceModel && !acceptedAny {
            route = .rulesOnly
            fallbackReason = "allOutputRejected"
        }
        IntelligenceTelemetry.record(route: route, fallbackReason: fallbackReason, rejectedFields: rejected)

        return EventUnderstandingResult(
            events: events,
            quality: analysis.quality,
            route: route,
            fallbackReason: fallbackReason,
            evidence: analysis.evidence,
            rejectedFieldCount: rejected
        )
    }

    enum PipelineError: String, Error {
        case timeout
    }

    /// Runs `work`, throwing `PipelineError.timeout` (and cancelling the work) if it exceeds `limit`.
    static func withTimeout<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw PipelineError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw PipelineError.timeout }
            return first
        }
    }
}

// MARK: - Observability
/// Privacy-safe logging: stages, durations, routes and counts only. Never logs OCR text, titles,
/// URLs or contact data.
enum IntelligenceTelemetry {
    private static let logger = Logger(subsystem: "com.datesnap.app", category: "intelligence")
    private static let signposter = OSSignposter(logger: logger)

    struct Span {
        let id: OSSignpostID
        let state: OSSignpostIntervalState
        let start: ContinuousClock.Instant
    }

    static func begin(_ stage: StaticString) -> Span {
        let id = signposter.makeSignpostID()
        return Span(id: id, state: signposter.beginInterval(stage, id: id), start: .now)
    }

    static func end(_ span: Span, _ stage: StaticString, detail: String) {
        signposter.endInterval(stage, span.state)
        let elapsed = span.start.duration(to: .now)
        logger.debug("stage=\(stage, privacy: .public) elapsed=\(elapsed, privacy: .public) \(detail, privacy: .public)")
    }

    static func record(route: EngineRoute, fallbackReason: String?, rejectedFields: Int) {
        logger.info("route=\(route.rawValue, privacy: .public) fallback=\(fallbackReason ?? "none", privacy: .public) rejectedFields=\(rejectedFields, privacy: .public)")
    }

    /// Whether the user changed a field after review (field name only).
    static func recordEdit(field: String) {
        logger.info("userEdited field=\(field, privacy: .public)")
    }
}

// MARK: - Materialization Bridge
extension EventInterpretationCandidate {
    /// Value snapshot for creating the canonical `EventCandidate` on the caller's SwiftData context.
    public func toExtractedData() -> ExtractedCandidateData {
        var data = ExtractedCandidateData(
            id: id,
            title: title.value,
            startDate: start.value,
            endDate: isAllDay ? nil : end.value,
            isAllDay: isAllDay,
            location: address.value,
            venueName: venue.value,
            rsvpUrl: rsvpUrl,
            confidenceScore: rankScore,
            yearAssumed: yearAssumed,
            rawTextSnippet: rawSnippet,
            dateConfidence: start.score,
            titleConfidence: title.score,
            confidenceTierRaw: ConfidenceTier.from(score: rankScore).rawValue,
            isAmbiguousDate: isAmbiguousDate && start.isAmbiguous,
            ambiguousFragment: ambiguousFragment,
            timeZoneIdentifier: timeZoneIdentifier,
            dedupeKey: dedupeKey,
            phoneNumber: phoneNumber,
            email: email,
            notes: notesSummary
        )
        if data.venueName == nil, let organizer = organizer.value { data.notes = [data.notes, "Presented by \(organizer)"].filter { !$0.isEmpty }.joined(separator: " · ") }
        return data
    }
}
