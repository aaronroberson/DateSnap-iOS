import Foundation
import CoreGraphics
import Testing
@testable import DateSnap

// MARK: - Labeled Fixtures
/// Synthetic, sanitized flyers (no real people or contact data) with hand labels.
struct LabeledFlyer: Sendable {
    var name: String
    var lines: [(String, CGFloat)]
    var locale = "en_US"
    /// nil = not an event (the scan should yield nothing).
    var expected: Expected?

    struct Expected: Sendable {
        var title: String
        var date: DateComponents          // year, month, day
        var start: DateComponents?        // hour, minute; nil = all-day
        var doors: DateComponents? = nil
        var venueContains: String? = nil
        var hasDeadline = false
        /// A question should be asked (materially ambiguous flyer).
        var expectsQuestion = false
    }
}

enum EvaluationFixtures {
    static let flyers: [LabeledFlyer] = [
        LabeledFlyer(name: "doors-show", lines: [("NEON SUNSET", 0.10), ("Saturday, October 17, 2026", 0.04), ("DOORS 7:00 PM", 0.04), ("SHOW 8:30 PM", 0.04), ("SKYBAR PENTHOUSE", 0.04)],
                     expected: .init(title: "NEON SUNSET", date: .init(year: 2026, month: 10, day: 17), start: .init(hour: 20, minute: 30), doors: .init(hour: 19, minute: 0), venueContains: "SKYBAR")),
        LabeledFlyer(name: "lounge-headliner", lines: [("SUMMER NIGHTS", 0.09), ("October 24, 2026", 0.04), ("7:00 PM Lounge Opens", 0.04), ("8:30 PM Headliner Set", 0.04), ("The Blue Room · 12 Harbor Way", 0.03)],
                     expected: .init(title: "SUMMER NIGHTS", date: .init(year: 2026, month: 10, day: 24), start: .init(hour: 20, minute: 30), doors: .init(hour: 19, minute: 0))),
        LabeledFlyer(name: "appointment", lines: [("Dr. Rivera Dental", 0.07), ("Routine cleaning", 0.04), ("Thursday, November 5, 2026 10:30 AM", 0.04), ("1200 Wilshire Blvd, Suite 402", 0.03)],
                     expected: .init(title: "Dr. Rivera Dental", date: .init(year: 2026, month: 11, day: 5), start: .init(hour: 10, minute: 30), venueContains: "1200 Wilshire")),
        LabeledFlyer(name: "gala-deadline", lines: [("Autumn Gala", 0.09), ("RSVP by October 3, 2026", 0.03), ("Saturday, October 17, 2026 at 7pm", 0.04), ("Grand Hall", 0.04)],
                     expected: .init(title: "Autumn Gala", date: .init(year: 2026, month: 10, day: 17), start: .init(hour: 19, minute: 0), venueContains: "Grand Hall", hasDeadline: true)),
        LabeledFlyer(name: "tickets-on-sale", lines: [("Harbor Lights Tour", 0.09), ("Tickets on sale September 5", 0.03), ("December 12, 2026 · 8 PM", 0.04), ("Civic Arena", 0.04)],
                     expected: .init(title: "Harbor Lights Tour", date: .init(year: 2026, month: 12, day: 12), start: .init(hour: 20, minute: 0), venueContains: "Civic Arena")),
        LabeledFlyer(name: "ambiguous-en001", lines: [("Book Club", 0.08), ("04/05/2027 7pm", 0.04), ("Central Library", 0.04)], locale: "en_001",
                     expected: .init(title: "Book Club", date: .init(year: 2027, month: 4, day: 5), start: .init(hour: 19, minute: 0), expectsQuestion: true)),
        LabeledFlyer(name: "en-gb-numeric", lines: [("Quiz Night", 0.08), ("14/11/2026 8pm", 0.04), ("The Crown", 0.04)], locale: "en_GB",
                     expected: .init(title: "Quiz Night", date: .init(year: 2026, month: 11, day: 14), start: .init(hour: 20, minute: 0))),
        LabeledFlyer(name: "time-window", lines: [("Farmers Market", 0.08), ("Sunday, October 18, 2026", 0.04), ("9am - 1pm", 0.04), ("Town Square", 0.04)],
                     expected: .init(title: "Farmers Market", date: .init(year: 2026, month: 10, day: 18), start: .init(hour: 9, minute: 0))),
        LabeledFlyer(name: "all-day", lines: [("Harvest Festival", 0.09), ("Saturday, October 31, 2026", 0.04), ("Riverside Park", 0.04)],
                     expected: .init(title: "Harvest Festival", date: .init(year: 2026, month: 10, day: 31), start: nil)),
        LabeledFlyer(name: "year-less", lines: [("Pottery Workshop", 0.08), ("November 21 · 2:00 PM", 0.04), ("Clay Studio", 0.04)],
                     expected: .init(title: "Pottery Workshop", date: .init(year: 2026, month: 11, day: 21), start: .init(hour: 14, minute: 0))),
        LabeledFlyer(name: "receipt", lines: [("CAFE GRATITUDE", 0.06), ("1x ESPRESSO $4.50", 0.03), ("SUBTOTAL $4.50", 0.03), ("TAX $0.40", 0.03), ("TOTAL $4.90", 0.03), ("10/02/2026 9:14 AM", 0.03)],
                     expected: nil),
        LabeledFlyer(name: "meme", lines: [("WHEN THE CODE COMPILES", 0.08), ("first try", 0.05)], expected: nil)
    ]
}

// MARK: - Evaluator
struct EvaluationReport: CustomStringConvertible {
    var route: String
    var total = 0
    var titleCorrect = 0
    var dateCorrect = 0
    var startCorrect = 0
    var doorsCorrect = 0, doorsTotal = 0
    var venueCorrect = 0, venueTotal = 0
    var deadlineCorrect = 0, deadlineTotal = 0
    var nonEventsRejected = 0, nonEventsTotal = 0
    var questionsAsked = 0, questionsWarranted = 0, questionsCorrect = 0
    var modelRuns = 0, fallbacks = 0
    var latency: Duration = .zero

    func rate(_ a: Int, _ b: Int) -> Double { b == 0 ? 1 : Double(a) / Double(b) }

    var description: String {
        """
        route=\(route) events=\(total) title=\(fmt(rate(titleCorrect, total))) date=\(fmt(rate(dateCorrect, total))) \
        start=\(fmt(rate(startCorrect, total))) doors/show=\(fmt(rate(doorsCorrect, doorsTotal))) venue=\(fmt(rate(venueCorrect, venueTotal))) \
        deadline=\(fmt(rate(deadlineCorrect, deadlineTotal))) nonEventRejection=\(fmt(rate(nonEventsRejected, nonEventsTotal))) \
        questionPrecision=\(fmt(rate(questionsCorrect, questionsAsked))) questionRecall=\(fmt(rate(questionsCorrect, questionsWarranted))) \
        modelRuns=\(modelRuns) fallbacks=\(fallbacks) latency=\(latency)
        """
    }

    private func fmt(_ value: Double) -> String { String(format: "%.2f", value) }
}

enum ExtractionEvaluator {
    static func evaluate(_ pipeline: EventUnderstandingProviding, route: String, anchor: Date) async -> EvaluationReport {
        var report = EvaluationReport(route: route)
        let calendar = Calendar.current
        for flyer in EvaluationFixtures.flyers {
            let ocr = makeOCR(flyer.lines)
            let clock = ContinuousClock.now
            let result = await pipeline.understand(ocr, locale: Locale(identifier: flyer.locale), anchor: anchor, assetIdentifier: flyer.name)
            report.latency += clock.duration(to: .now)
            if result.route == .onDeviceModel { report.modelRuns += 1 }
            if result.fallbackReason.map({ ["timeout", "modelError", "allOutputRejected", "cancelled"].contains($0) }) == true { report.fallbacks += 1 }

            guard let expected = flyer.expected else {
                report.nonEventsTotal += 1
                if result.events.isEmpty { report.nonEventsRejected += 1 }
                continue
            }
            report.total += 1
            guard let event = result.events.first else {
                if expected.expectsQuestion { report.questionsWarranted += 1 }
                continue
            }
            let best = event.best
            let day = calendar.dateComponents([.year, .month, .day], from: best.start.value)
            let time = calendar.dateComponents([.hour, .minute], from: best.start.value)

            if DateInference.normalizeText(best.title.value) == DateInference.normalizeText(expected.title) { report.titleCorrect += 1 }
            if day == expected.date { report.dateCorrect += 1 }
            if let start = expected.start {
                if !best.isAllDay && time == start { report.startCorrect += 1 }
            } else if best.isAllDay {
                report.startCorrect += 1
            }
            if let doors = expected.doors {
                report.doorsTotal += 1
                if time == expected.start, let actual = best.doorsTime, calendar.dateComponents([.hour, .minute], from: actual) == doors {
                    report.doorsCorrect += 1
                }
            }
            if let venue = expected.venueContains {
                report.venueTotal += 1
                let text = [best.venue.value, best.address.value].compactMap { $0 }.joined(separator: " ")
                if text.localizedCaseInsensitiveContains(venue) { report.venueCorrect += 1 }
            }
            if expected.hasDeadline {
                report.deadlineTotal += 1
                if event.actions.contains(where: { $0.deadline != nil }) { report.deadlineCorrect += 1 }
            }
            if expected.expectsQuestion { report.questionsWarranted += 1 }
            if !event.questions.isEmpty {
                report.questionsAsked += 1
                if expected.expectsQuestion { report.questionsCorrect += 1 }
            }
        }
        return report
    }

    /// Distinct fixtures must never cluster together; a re-shot of the same flyer must.
    static func duplicateFalseMergeRate(anchor: Date) async -> (falseMerges: Int, pairs: Int, sameEventMatched: Bool) {
        var entries: [EventSimilarityService.Entry] = []
        for flyer in EvaluationFixtures.flyers where flyer.expected != nil {
            let result = await EventUnderstandingPipeline.rulesOnly().understand(makeOCR(flyer.lines), locale: Locale(identifier: flyer.locale), anchor: anchor, assetIdentifier: flyer.name)
            if let best = result.events.first?.best {
                entries.append(.init(id: flyer.name, similarityKey: best.similarityKey, title: best.title.value, start: best.start.value, isSaved: true))
            }
        }
        let clusters = EventSimilarityService.clusters(entries)
        let pairs = entries.count * (entries.count - 1) / 2
        let falseMerges = clusters.reduce(0) { $0 + $1.count * ($1.count - 1) / 2 }

        // Same flyer, different screenshot (slightly different crop/casing and asset).
        let first = EvaluationFixtures.flyers[0]
        let reshot = makeOCR(first.lines.map { ($0.0.capitalized, $0.1 * 0.9) })
        let again = await EventUnderstandingPipeline.rulesOnly().understand(reshot, locale: Locale(identifier: "en_US"), anchor: anchor, assetIdentifier: "reshot")
        let reshotEntry = again.events.first.map {
            EventSimilarityService.Entry(id: "reshot", similarityKey: $0.best.similarityKey, title: $0.best.title.value, start: $0.best.start.value, isSaved: false)
        }
        let matched = reshotEntry.map { !EventSimilarityService.matches(for: $0, among: entries).filter { $0.entry.id == first.name }.isEmpty } ?? false
        return (falseMerges, pairs, matched)
    }
}

// MARK: - Release Gates
@Suite("Extraction evaluation")
struct ExtractionEvaluationTests {
    @Test("Rules-only route meets release thresholds on the labeled set")
    func rulesOnlyThresholds() async {
        let report = await ExtractionEvaluator.evaluate(EventUnderstandingPipeline.rulesOnly(), route: "rulesOnly", anchor: testAnchor)
        print(report)
        // Thresholds set from the hand-labeled baseline; raise them as the corpus and engine improve.
        #expect(report.rate(report.titleCorrect, report.total) >= 0.9)
        #expect(report.rate(report.dateCorrect, report.total) >= 0.9)
        #expect(report.rate(report.startCorrect, report.total) >= 0.9)
        #expect(report.rate(report.doorsCorrect, report.doorsTotal) == 1)
        #expect(report.rate(report.deadlineCorrect, report.deadlineTotal) == 1)
        #expect(report.rate(report.nonEventsRejected, report.nonEventsTotal) == 1)
        #expect(report.rate(report.questionsCorrect, report.questionsAsked) >= 0.99)
        #expect(report.rate(report.questionsCorrect, report.questionsWarranted) >= 0.99)
        #expect(report.modelRuns == 0)
    }

    @Test("Duplicate clustering never merges distinct events but matches a re-shot flyer")
    func duplicateFalseMerges() async {
        let outcome = await ExtractionEvaluator.duplicateFalseMergeRate(anchor: testAnchor)
        print("duplicates falseMerges=\(outcome.falseMerges)/\(outcome.pairs) reshotMatched=\(outcome.sameEventMatched)")
        #expect(outcome.falseMerges == 0)
        #expect(outcome.sameEventMatched)
    }

    /// Opt-in (DATESNAP_EVAL_LIVE=1): runs the corpus through the live route when Apple Intelligence is available.
    @Test("Live route report", .enabled(if: ProcessInfo.processInfo.environment["DATESNAP_EVAL_LIVE"] == "1"))
    func liveRouteReport() async {
        let report = await ExtractionEvaluator.evaluate(IntelligenceComposition.liveUnderstanding(), route: "live", anchor: testAnchor)
        print(report)
        // The model may only improve on, never regress, validated fields relative to rules.
        let rules = await ExtractionEvaluator.evaluate(EventUnderstandingPipeline.rulesOnly(), route: "rulesOnly", anchor: testAnchor)
        #expect(report.rate(report.dateCorrect, report.total) >= rules.rate(rules.dateCorrect, rules.total))
        #expect(report.rate(report.nonEventsRejected, report.nonEventsTotal) == 1)
    }
}
