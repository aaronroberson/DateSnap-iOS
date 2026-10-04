import Foundation
import CoreGraphics
import Testing
@testable import DateSnap

/// Builds an OCR result with top-to-bottom lines; larger `size` means larger type.
func makeOCR(_ lines: [(String, CGFloat)], confidence: Float = 0.95) -> OCRResult {
    var y: CGFloat = 0.95
    let ocrLines = lines.map { text, size -> OCRLine in
        y -= size + 0.02
        return OCRLine(text: text, confidence: confidence, boundingBox: CGRect(x: 0.1, y: y, width: 0.8, height: size))
    }
    return OCRResult(fullText: lines.map(\.0).joined(separator: "\n"), lines: ocrLines, meanConfidence: confidence)
}

let testAnchor: Date = {
    NSTimeZone.default = TimeZone(secondsFromGMT: 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12))!
}()

let testFutureDate: Date = {
    testCalendar.date(from: DateComponents(year: 2030, month: 9, day: 1, hour: 12))!
}()

var testCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}

@Suite("Rule-based event understanding")
struct RuleBasedEventAnalyzerTests {
    let flyer = makeOCR([
        ("NEON SUNSET", 0.10),
        ("Presented by Void Acoustics", 0.03),
        ("SATURDAY, OCTOBER 17, 2026", 0.04),
        ("DOORS 7:00 PM", 0.04),
        ("SHOW 8:30 PM", 0.04),
        ("SKYBAR PENTHOUSE", 0.04),
        ("8440 Sunset Blvd, West Hollywood, CA", 0.03),
        ("RSVP by Oct 10 at datesnap.app/rsvp", 0.03),
        ("21+ · $25 · Every Saturday", 0.03)
    ])

    func analyze(_ result: OCRResult) -> RuleBasedEventAnalyzer.Analysis {
        let extracted = EventExtractionCore.extract(from: result, locale: Locale(identifier: "en_US"), anchor: testAnchor)
        return RuleBasedEventAnalyzer.analyze(result: result, extracted: extracted, locale: Locale(identifier: "en_US"), anchor: testAnchor)
    }

    @Test("Temporal fragments are labeled by role")
    func temporalRoles() {
        let temporal = analyze(flyer).events.first?.temporalEvidence ?? []
        #expect(temporal.contains { $0.role == .doors && $0.hour == 19 })
        #expect(temporal.contains { $0.role == .show && $0.hour == 20 && $0.minute == 30 })
        #expect(temporal.contains { $0.role == .rsvpDeadline && $0.date != nil })
        #expect(temporal.contains { $0.role == .eventDate })
    }

    @Test("Baseline interpretation keeps evidence, provenance and doors")
    func baselineCandidate() throws {
        let analysis = analyze(flyer)
        let best = try #require(analysis.events.first?.best)
        #expect(best.title.value == "NEON SUNSET")
        #expect(!best.title.evidence.isEmpty)
        #expect(testCalendar.component(.hour, from: best.start.value) == 20)
        #expect(best.start.provenance == .explicitText)
        #expect(best.doorsTime.map { testCalendar.component(.hour, from: $0) } == 19)
        #expect(best.organizer.value == "Void Acoustics")
        #expect(best.address.value == "8440 Sunset Blvd, West Hollywood, CA")
        #expect(best.durationSource == .categoryDefault)
        #expect(best.end.provenance == .fallbackDefault)
        #expect(best.notesSummary.contains("Doors open at 7:00 PM"))
        #expect(best.notesSummary.contains("Ages: 21+"))
        #expect(best.notesSummary.contains("Price: $25"))
        #expect(best.start.reason?.contains("SHOW 8:30 PM") == true)
        #expect(best.end.reason?.contains("2-hour") == true)
    }

    @Test("Actions carry exact targets and the RSVP deadline; recurrence is a suggestion")
    func actionsAndRecurrence() throws {
        let event = try #require(analyze(flyer).events.first)
        let rsvp = try #require(event.actions.first { $0.kind == .rsvp })
        #expect(rsvp.target.contains("datesnap.app/rsvp"))
        #expect(rsvp.deadline != nil)
        #expect(event.recurrence?.kind == .weekly)
    }

    @Test("Scan quality flags text without date cues and receipts")
    func scanQuality() {
        #expect(RuleBasedEventAnalyzer.qualityReport(for: flyer, anchor: testAnchor).isScanWorthy)
        let meme = makeOCR([("WHEN THE CODE COMPILES", 0.08), ("first try", 0.05)])
        let report = RuleBasedEventAnalyzer.qualityReport(for: meme, anchor: testAnchor)
        #expect(report.isScanWorthy == false)
        #expect(report.reasons.contains("noDateOrTimeCue"))
    }

    @Test("Similarity key ignores asset identity and casing but not the day")
    func similarityKey() {
        let date = testAnchor
        let a = RuleBasedEventAnalyzer.similarityKey(title: "Neon Sunset", start: date, venue: "Skybar Penthouse")
        let b = RuleBasedEventAnalyzer.similarityKey(title: "NEON  SUNSET!", start: date.addingTimeInterval(3600), venue: "SKYBAR")
        let c = RuleBasedEventAnalyzer.similarityKey(title: "Neon Sunset", start: date.addingTimeInterval(86400 * 7), venue: "Skybar")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Category drives an editable duration suggestion, not the saved end")
    func categoryDuration() {
        #expect(RuleBasedEventAnalyzer.classifyCategory(text: "Dr. Aris DDS routine cleaning") == .appointment)
        #expect(RuleBasedEventAnalyzer.classifyCategory(text: "Swift Summit keynote") == .conference)
        #expect(EventDurationPolicy.suggestedDuration(for: .appointment) == 3600)
        #expect(EventDurationPolicy.fallback == 7200)
    }

    @Test("Triggers fire only when the baseline needs help")
    func triggers() {
        let clear = makeOCR([("Book Club", 0.08), ("October 20, 2026 at 7pm", 0.04), ("Central Library", 0.03)])
        #expect(analyze(clear).triggers.isEmpty)
        let ambiguous = makeOCR([("Book Club", 0.08), ("04/05/2027 7pm", 0.04)])
        let extracted = EventExtractionCore.extract(from: ambiguous, locale: Locale(identifier: "en_001"), anchor: testAnchor)
        let analysis = RuleBasedEventAnalyzer.analyze(result: ambiguous, extracted: extracted, locale: Locale(identifier: "en_001"), anchor: testAnchor)
        #expect(analysis.triggers.contains("ambiguousDate"))
    }
}
