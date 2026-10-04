import Foundation
import Testing
@testable import DateSnap

@Suite("Evidence validation, ranking and questions")
struct EvidenceValidationTests {
    let locale = Locale(identifier: "en_US")
    let poster = makeOCR([
        ("SUMMER NIGHTS", 0.09),
        ("ROOFTOP SESSIONS VOL. 4", 0.08),
        ("Presented by Void Acoustics", 0.03),
        ("October 17, 2026", 0.04),
        ("7:00 PM Lounge Opens", 0.04),
        ("8:30 PM Headliner Set", 0.04),
        ("The Skybar", 0.04)
    ])

    func analysis() -> RuleBasedEventAnalyzer.Analysis {
        let extracted = EventExtractionCore.extract(from: poster, locale: locale, anchor: testAnchor, calendar: testCalendar)
        return RuleBasedEventAnalyzer.analyze(result: poster, extracted: extracted, locale: locale, anchor: testAnchor, calendar: testCalendar)
    }

    @Test("Grounded hypotheses are merged with model provenance")
    func acceptsGroundedValues() throws {
        let a = analysis()
        let baseline = try #require(a.events.first?.best)
        let hypothesis = EventHypothesis(
            titleLineID: 0, titleText: "Summer Nights",
            venueLineID: 6, venueText: "The Skybar",
            organizerLineID: 2, organizerText: "Void Acoustics",
            dateLineID: 3,
            startTimeLineID: 5, startTimeText: "8:30 PM",
            doorsTimeLineID: 4, doorsTimeText: "7:00 PM",
            category: "concert",
            reason: "The headliner set is the main event; the lounge opening is doors."
        )
        let outcome = EvidenceValidator.validate(hypothesis, against: baseline, evidence: a.evidence, locale: locale, anchor: testAnchor, calendar: testCalendar)
        let merged = try #require(outcome.candidate)
        #expect(outcome.rejectedFields.isEmpty)
        #expect(merged.title.value == "SUMMER NIGHTS")
        #expect(merged.title.provenance == .modelInterpretation)
        #expect(testCalendar.dateComponents([.hour, .minute], from: merged.start.value) == DateComponents(hour: 20, minute: 30))
        #expect(merged.doorsTime.map { testCalendar.component(.hour, from: $0) } == 19)
        #expect(merged.category == .concert)
        #expect(merged.start.evidence.contains { $0.lineID == 5 })
    }

    @Test("Ungrounded values are rejected, not invented")
    func rejectsUngroundedValues() throws {
        let a = analysis()
        let baseline = try #require(a.events.first?.best)
        let hypothesis = EventHypothesis(
            titleLineID: 0, titleText: "Summer Nights Festival 2026",   // not in the line
            venueLineID: 99, venueText: "Madison Square Garden",       // no such line
            dateLineID: 6,                                              // line has no date
            startTimeLineID: 5, startTimeText: "9:45 PM",               // not in the line
            category: "rave",                                           // not a category
            notesSummary: "Tickets at https://scam.example"             // introduces a link
        )
        let outcome = EvidenceValidator.validate(hypothesis, against: baseline, evidence: a.evidence, locale: locale, anchor: testAnchor, calendar: testCalendar)
        #expect(outcome.candidate == nil)
        #expect(Set(outcome.rejectedFields).isSuperset(of: ["title", "venue", "date", "startTime", "category", "notes"]))
    }

    @Test("A model start on a doors/opening line loses to a show-labeled time")
    func doorsLineCannotBeStart() throws {
        let a = analysis()
        let baseline = try #require(a.events.first?.best)
        // Rules already pick the headliner set (line 5) because "Lounge Opens" reads as doors.
        #expect(testCalendar.component(.hour, from: baseline.start.value) == 20)
        let hypothesis = EventHypothesis(startTimeLineID: 4, startTimeText: "7:00 PM", doorsTimeLineID: 4, doorsTimeText: "7:00 PM",
                                         reason: "startTimeLine")
        let outcome = EvidenceValidator.validate(hypothesis, against: baseline, evidence: a.evidence, locale: locale, anchor: testAnchor, calendar: testCalendar)
        #expect(outcome.rejectedFields.contains("startTime"))
        let merged = outcome.candidate
        #expect(merged.map { testCalendar.component(.hour, from: $0.start.value) } ?? 20 == 20)
        #expect(merged?.explanations.isEmpty ?? true)
    }

    @Test("A contradicting model date cannot override an explicit high-confidence date")
    func explicitDateStaysAuthoritative() throws {
        let a = analysis()
        var baseline = try #require(a.events.first?.best)
        baseline.start.score = 0.95
        var model = baseline
        model.id = "model"
        model.start.value = baseline.start.value.addingTimeInterval(86400 * 3)
        model.start.provenance = .modelInterpretation
        model.start.score = 0.99
        let ranked = InterpretationRanker.rank(baseline: baseline, modelCandidate: model, deterministicAlternatives: [], ocrMeanConfidence: 0.95)
        #expect(ranked.best.id == baseline.id)
        #expect(ranked.alternatives.map(\.id) == ["model"])
    }

    @Test("Ambiguous dates produce a swapped alternative and a date question")
    func ambiguousDateQuestion() throws {
        let ocr = makeOCR([("Book Club", 0.08), ("04/05/2027 7pm", 0.04)])
        let loc = Locale(identifier: "en_001")
        let extracted = EventExtractionCore.extract(from: ocr, locale: loc, anchor: testAnchor, calendar: testCalendar)
        let a = RuleBasedEventAnalyzer.analyze(result: ocr, extracted: extracted, locale: loc, anchor: testAnchor, calendar: testCalendar)
        let baseline = try #require(a.events.first?.best)
        let alternatives = InterpretationRanker.deterministicAlternatives(for: baseline, titleCandidates: [])
        #expect(alternatives.count == 1)
        let swapped = try #require(alternatives.first)
        #expect(testCalendar.dateComponents([.month, .day], from: swapped.start.value) == DateComponents(month: 5, day: 4))

        let ranked = InterpretationRanker.rank(baseline: baseline, modelCandidate: nil, deterministicAlternatives: alternatives, ocrMeanConfidence: 0.95)
        let questions = InterpretationRanker.questions(best: ranked.best, alternatives: ranked.alternatives)
        #expect(questions.first?.field == .date)
        #expect(questions.first?.options.count == 2)
    }

    @Test("Immaterial alternatives are dropped and no question is asked")
    func noQuestionWhenImmaterial() throws {
        let baseline = try #require(analysis().events.first?.best)
        var nearCopy = baseline
        nearCopy.id = "near"
        nearCopy.start.value = baseline.start.value.addingTimeInterval(5 * 60)
        let ranked = InterpretationRanker.rank(baseline: baseline, modelCandidate: nearCopy, deterministicAlternatives: [], ocrMeanConfidence: 0.9)
        #expect(ranked.alternatives.isEmpty)
        #expect(InterpretationRanker.questions(best: ranked.best, alternatives: ranked.alternatives).isEmpty)
    }

    @Test("Requests are bounded before reaching the model")
    func boundedRequest() {
        let lines = (0..<200).map { EvidenceLine(id: $0, blockID: 0, text: String(repeating: "x", count: 300), confidence: 1, boundingBox: .zero, fontRank: $0) }
        let request = InterpretationRequest(lines: lines, referenceDate: testAnchor, localeIdentifier: "en_US", timeZoneIdentifier: "UTC", baseline: [], triggers: [])
        let bounded = request.bounded(by: IntelligencePolicy())
        #expect(bounded.lines.count <= 60)
        #expect(bounded.lines.allSatisfy { $0.text.count <= 200 })
        #expect(bounded.lines.reduce(0) { $0 + $1.text.count } <= 3000)
    }
}
