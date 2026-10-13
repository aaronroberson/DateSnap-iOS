import Foundation
import CoreGraphics
import Testing
@testable import Pencild

/// Real-world screenshots: only text that names a day may create an event.
@Suite("Screenshot grounding")
struct ScreenshotGroundingTests {
    /// Lines as Vision reports them: each box is as wide as its text, so body copy is wide and a
    /// short headline is narrow even when it is the largest type on screen.
    private func screenshot(_ lines: [(String, CGFloat)]) -> OCRResult {
        var y: CGFloat = 0.97
        let ocrLines = lines.map { text, size -> OCRLine in
            y -= size + 0.02
            let width = min(0.92, CGFloat(text.count) * size * 0.55)
            return OCRLine(text: text, confidence: 0.95, boundingBox: CGRect(x: 0.04, y: y, width: width, height: size))
        }
        return OCRResult(fullText: lines.map(\.0).joined(separator: "\n"), lines: ocrLines, meanConfidence: 0.95)
    }

    private func extract(_ result: OCRResult) -> [ExtractedCandidateData] {
        EventExtractionCore.extract(from: result, locale: Locale(identifier: "en_US"), anchor: testAnchor, calendar: testCalendar)
    }

    @Test("A status-bar clock does not turn a chat screenshot into an event")
    func statusBarClockIsNotADate() {
        let chat = screenshot([
            ("9:41", 0.02),
            ("Messages", 0.03),
            ("Did you see the game last night?", 0.025),
            ("Haha yes, unreal ending", 0.025),
            ("iMessage", 0.02),
        ])
        #expect(extract(chat).isEmpty)
    }

    @Test("A time with no day is not an event date")
    func bareTimeIsNotADate() {
        let note = screenshot([
            ("10:15", 0.02),
            ("Grocery list", 0.06),
            ("Eggs, milk, coffee beans", 0.03),
            ("Pick up around 6:30", 0.03),
        ])
        #expect(extract(note).isEmpty)
    }

    @Test("A screenshot that names a day still produces its event")
    func namedDayStillProduces() {
        let post = screenshot([
            ("9:41", 0.02),
            ("Book club meets Thursday, Sept 24 at 7 PM", 0.03),
        ])
        let candidates = extract(post)
        #expect(candidates.count == 1)
        #expect(testCalendar.component(.day, from: candidates.first?.startDate ?? .distantPast) == 24)
        // The status-bar clock must not become the start time.
        #expect(testCalendar.component(.hour, from: candidates.first?.startDate ?? .distantPast) == 19)
    }
}
