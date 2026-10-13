import Foundation
import CoreGraphics
import Testing
@testable import Pencild

/// Real-world screenshots: only text that names a day may create an event, and the largest
/// headline wins the title over body copy.
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

    @Test("The large headline wins the title over a longer description line")
    func headlineBeatsDescription() {
        let flyer = screenshot([
            ("SUMMER JAZZ NIGHT", 0.11),
            ("Join us for an evening of live music under the stars with local trios", 0.03),
            ("Friday, October 9, 2026 · 7 PM", 0.035),
            ("Riverside Park Amphitheater", 0.03),
        ])
        #expect(extract(flyer).first?.title == "SUMMER JAZZ NIGHT")
    }

    @Test("A headline below the status bar and app chrome still wins the title")
    func headlineBelowChromeWins() {
        let story = screenshot([
            ("9:41", 0.02),
            ("< Back", 0.025),
            ("Pottery Workshop", 0.09),
            ("Learn wheel throwing basics in a relaxed, beginner friendly two hour session", 0.028),
            ("Sat Oct 3 · 10 AM", 0.03),
        ])
        #expect(extract(story).first?.title == "Pottery Workshop")
    }

    @Test("A short, large headline beats a wide subtitle line in the top of the image")
    func shortHeadlineBeatsWideSubtitle() {
        let flyer = screenshot([
            ("Open Mic", 0.06),
            ("Every Thursday at The Copper Kettle Cafe", 0.035),
            ("Thursday, Oct 8 · 7 PM", 0.03),
        ])
        #expect(extract(flyer).first?.title == "Open Mic")
    }

    @Test("A headline containing a common flyer word still wins the title")
    func headlineWithFlyerWordWins() {
        let flyer = screenshot([
            ("FREE LIVE JAZZ", 0.1),
            ("Bring a blanket and enjoy an evening of music on the lawn", 0.03),
            ("Saturday, October 10 · 6 PM", 0.03),
        ])
        #expect(extract(flyer).first?.title == "FREE LIVE JAZZ")
    }
}
