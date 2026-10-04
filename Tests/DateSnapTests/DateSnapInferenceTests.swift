import Foundation
import Testing
@testable import DateSnap

@Suite("DateInference & Extraction Engine Tests")
struct DateSnapInferenceTests {

    // MARK: - 1. Relative Dates Tests

    @Test("Relative date phrases resolve relative to deterministic anchor")
    func testRelativeDates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Anchor: Wednesday, Oct 14, 2026, 12:00 UTC
        var anchorComps = DateComponents()
        anchorComps.year = 2026
        anchorComps.month = 10
        anchorComps.day = 14
        anchorComps.hour = 12
        anchorComps.minute = 0
        let anchor = calendar.date(from: anchorComps)!

        // "Tomorrow"
        let tmrwResult = DateInference.resolveRelativePhrases(in: "Party tomorrow at the club", anchor: anchor, calendar: calendar)
        #expect(tmrwResult != nil)
        let tmrwComps = calendar.dateComponents([.year, .month, .day], from: tmrwResult!.date)
        #expect(tmrwComps.year == 2026)
        #expect(tmrwComps.month == 10)
        #expect(tmrwComps.day == 15)

        // "Tonight"
        let tonightResult = DateInference.resolveRelativePhrases(in: "Concert tonight doors open", anchor: anchor, calendar: calendar)
        #expect(tonightResult != nil)
        let tonightComps = calendar.dateComponents([.year, .month, .day, .hour], from: tonightResult!.date)
        #expect(tonightComps.day == 14)
        #expect(tonightComps.hour == 19)

        // "in 3 days"
        let inDaysResult = DateInference.resolveRelativePhrases(in: "Meetup in 3 days", anchor: anchor, calendar: calendar)
        #expect(inDaysResult != nil)
        let inDaysComps = calendar.dateComponents([.day], from: inDaysResult!.date)
        #expect(inDaysComps.day == 17)

        // "this Friday" (anchor is Wednesday Oct 14 -> Friday is Oct 16)
        let thisFridayResult = DateInference.resolveRelativePhrases(in: "Live session this friday", anchor: anchor, calendar: calendar)
        #expect(thisFridayResult != nil)
        let friComps = calendar.dateComponents([.day], from: thisFridayResult!.date)
        #expect(friComps.day == 16)

        // "next Friday" (strictly following week: 2 + 7 = 9 days ahead -> Oct 23)
        let nextFridayResult = DateInference.resolveRelativePhrases(in: "Big gala next friday", anchor: anchor, calendar: calendar)
        #expect(nextFridayResult != nil)
        let nextFriComps = calendar.dateComponents([.day], from: nextFridayResult!.date)
        #expect(nextFriComps.day == 23)
    }

    // MARK: - 2. Locale-Aware Numeric Disambiguation Tests

    @Test("Ambiguous numerics resolve differently across en_US, en_GB, de_DE, and en_001")
    func testNumericDateLocaleDisambiguation() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = testAnchor

        let timeDummy: DateInference.TimeInfo = (hasTime: false, startHour: nil, startMinute: nil, endHour: nil, endMinute: nil, doorsHour: nil, doorsMinute: nil)

        // Text with "07/08/2026"
        let text = "Event on 07/08/2026 at venue"

        // en_US -> Month = 7 (July), Day = 8
        let usLocale = Locale(identifier: "en_US")
        let usMatch = DateInference.detectNumericDate(in: text, locale: usLocale, anchor: anchor, calendar: calendar, timeInfo: timeDummy)
        #expect(usMatch != nil)
        let usComps = calendar.dateComponents([.month, .day, .year], from: usMatch!.startDate)
        #expect(usComps.month == 7)
        #expect(usComps.day == 8)
        #expect(usMatch?.isAmbiguous == false)

        // en_GB -> Day = 7, Month = 8 (August)
        let gbLocale = Locale(identifier: "en_GB")
        let gbMatch = DateInference.detectNumericDate(in: text, locale: gbLocale, anchor: anchor, calendar: calendar, timeInfo: timeDummy)
        #expect(gbMatch != nil)
        let gbComps = calendar.dateComponents([.month, .day, .year], from: gbMatch!.startDate)
        #expect(gbComps.month == 8)
        #expect(gbComps.day == 7)
        #expect(gbMatch?.isAmbiguous == false)

        // de_DE -> Day = 7, Month = 8 (August)
        let deLocale = Locale(identifier: "de_DE")
        let deMatch = DateInference.detectNumericDate(in: text, locale: deLocale, anchor: anchor, calendar: calendar, timeInfo: timeDummy)
        #expect(deMatch != nil)
        let deComps = calendar.dateComponents([.month, .day, .year], from: deMatch!.startDate)
        #expect(deComps.month == 8)
        #expect(deComps.day == 7)

        // Unambiguous: 25/08/2026 (first number > 12 is always day)
        let unambiguousText = "Concert on 25/08/2026"
        let unamMatch = DateInference.detectNumericDate(in: unambiguousText, locale: usLocale, anchor: anchor, calendar: calendar, timeInfo: timeDummy)
        #expect(unamMatch != nil)
        let unamComps = calendar.dateComponents([.month, .day], from: unamMatch!.startDate)
        #expect(unamComps.month == 8)
        #expect(unamComps.day == 25)
        #expect(unamMatch?.isAmbiguous == false)
    }

    // MARK: - 3. Assumed Year & Leap-Year Rollover Tests

    @Test("Assumed Year rolls past dates to next year and handles Feb 29 leap years")
    func testAssumedYearRolloverAndLeapYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        // Anchor: Nov 15, 2025
        var anchorComps = DateComponents()
        anchorComps.year = 2025
        anchorComps.month = 11
        anchorComps.day = 15
        let anchor = calendar.date(from: anchorComps)!

        // Event text with "July 18" (no year) -> since July 18, 2025 is before Nov 15, rolls to 2026
        let (resolvedJuly, assumedJuly) = DateInference.resolveAssumedYear(
            month: 7,
            day: 18,
            hour: 19,
            minute: 0,
            explicitYear: nil,
            text: "Party on July 18",
            anchor: anchor,
            calendar: calendar
        )
        #expect(assumedJuly == true)
        let julyComps = calendar.dateComponents([.year, .month, .day], from: resolvedJuly)
        #expect(julyComps.year == 2026)
        #expect(julyComps.month == 7)
        #expect(julyComps.day == 18)

        // Event text with "December 20" (no year) -> since Dec 20, 2025 is after Nov 15, stays in 2025
        let (resolvedDec, assumedDec) = DateInference.resolveAssumedYear(
            month: 12,
            day: 20,
            hour: 18,
            minute: 0,
            explicitYear: nil,
            text: "Holiday Mixer on December 20",
            anchor: anchor,
            calendar: calendar
        )
        #expect(assumedDec == true)
        let decComps = calendar.dateComponents([.year, .month, .day], from: resolvedDec)
        #expect(decComps.year == 2025)

        // Feb 29 in non-leap year (e.g. 2025 anchor) rolls to next valid leap year (2028)
        let (resolvedFeb29, _) = DateInference.resolveAssumedYear(
            month: 2,
            day: 29,
            hour: 12,
            minute: 0,
            explicitYear: nil,
            text: "Leap day gala Feb 29",
            anchor: anchor,
            calendar: calendar
        )
        let leapComps = calendar.dateComponents([.year, .month, .day], from: resolvedFeb29)
        #expect(leapComps.year == 2028)
        #expect(leapComps.month == 2)
        #expect(leapComps.day == 29)
    }

    // MARK: - 4. Multi-Date Range Expansion Tests

    @Test("Date ranges expand into bounded daily event candidates")
    func testDateRangeExpansion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var anchorComps = DateComponents()
        anchorComps.year = 2026
        anchorComps.month = 1
        anchorComps.day = 1
        let anchor = calendar.date(from: anchorComps)!

        let timeDummy: DateInference.TimeInfo = (hasTime: false, startHour: nil, startMinute: nil, endHour: nil, endMinute: nil, doorsHour: nil, doorsMinute: nil)
 
         let rangeText = "Annual Innovation Summit\nOctober 12-14, 2026\nConvention Center"
         let detected = DateInference.detectMonthDates(in: rangeText, anchor: anchor, calendar: calendar, timeInfo: timeDummy)
 
         #expect(detected.count == 3) // Oct 12, Oct 13, Oct 14
         let days = detected.map { calendar.component(.day, from: $0.startDate) }
         #expect(days == [12, 13, 14])
         for item in detected {
             #expect(calendar.component(.month, from: item.startDate) == 10)
             #expect(calendar.component(.year, from: item.startDate) == 2026)
         }
     }
 
     // MARK: - 5. Doors vs Show Windows Tests
 
     @Test("Time windows and doors vs show times are parsed accurately")
     func testTimeWindowsAndDoors() {
         // Window with hyphen
         let windowText = "DOORS OPEN 7:00 PM – 11:30 PM\nSKYBAR"
         let parsedWindow = DateInference.parseTimesAndWindows(in: windowText)
         #expect(parsedWindow.hasTime == true)
         #expect(parsedWindow.startHour == 19)
         #expect(parsedWindow.startMinute == 0)
         #expect(parsedWindow.endHour == 23)
         #expect(parsedWindow.endMinute == 30)
 
         // Doors vs Show markers: Show is primary start time (20:30), doors preserved (19:00)
         let doorsShowText = "Doors 7:00 PM\nShow 8:30 PM\nMain Stage"
         let parsedDoors = DateInference.parseTimesAndWindows(in: doorsShowText)
         #expect(parsedDoors.hasTime == true)
         #expect(parsedDoors.startHour == 20)
         #expect(parsedDoors.startMinute == 30)
         #expect(parsedDoors.doorsHour == 19)
         #expect(parsedDoors.doorsMinute == 0)
         #expect(DateInference.doorsNote(in: doorsShowText) == "Doors open at 7:00 PM")
         // Doors + show on one line, with a later end time
         let oneLine = DateInference.parseTimesAndWindows(in: "DOORS 6PM / SHOW 7:30PM\nCURFEW 11PM")
         #expect(oneLine.startHour == 19)
         #expect(oneLine.startMinute == 30)
         #expect(oneLine.endHour == 23)
         #expect(oneLine.doorsHour == 18)

         // Doors alone (no show time) stays the start, with no separate doors note
         let doorsOnly = DateInference.parseTimesAndWindows(in: "Doors open 8 PM")
         #expect(doorsOnly.startHour == 20)
         #expect(doorsOnly.doorsHour == nil)
         #expect(DateInference.doorsNote(in: "Doors open 8 PM") == nil)

        // Noon and Midnight
        #expect(DateInference.parseSingleTime("noon")?.hour == 12)
        #expect(DateInference.parseSingleTime("midnight")?.hour == 0)
    }

    @Test("A year followed by a time is not misread as a time window")
    func testYearFollowedByTime() {
        // "…/2027 7pm" must not be read as a 27:00–7pm window
        let parsed = DateInference.parseTimesAndWindows(in: "Book club\n04/05/2027 7pm\nLibrary")
        #expect(parsed.startHour == 19)
        #expect(parsed.endHour == nil)
        #expect(DateInference.parseSingleTime("27") == nil)

        let monthName = DateInference.parseTimesAndWindows(in: "JULY 18 2025 7:00 PM")
        #expect(monthName.startHour == 19)
        #expect(monthName.startMinute == 0)
    }

    @Test("Explicit years are detected relative to the anchor, not a fixed window")
    func testAnchorRelativeExplicitYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let anchor = calendar.date(from: DateComponents(year: 2040, month: 3, day: 1))!

        // 2041 was outside the old 2024–2039 window
        #expect(DateInference.findExplicitYear(in: "Gala · May 2 2041", anchor: anchor, calendar: calendar) == 2041)
        // Implausible years (street numbers, distant history) are ignored
        #expect(DateInference.findExplicitYear(in: "1901 Sunset Blvd", anchor: anchor, calendar: calendar) == nil)
        // Part of a time or numeric date is not a year
        #expect(DateInference.findExplicitYear(in: "Doors 20:45", anchor: anchor, calendar: calendar) == nil)

        let resolved = DateInference.resolveAssumedYear(
            month: 5, day: 2, hour: 19, minute: 0, explicitYear: nil,
            text: "Gala · May 2 2041", anchor: anchor, calendar: calendar
        )
        #expect(resolved.yearAssumed == false)
        #expect(calendar.component(.year, from: resolved.date) == 2041)
    }

    @Test("RSVP deadlines and on-sale dates are not taken as the event date")
    func testDeadlineIsNotEventDate() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!
        let text = "Autumn Gala\nRSVP by October 3, 2026\nSaturday, October 17, 2026 at 7pm\nTickets on sale September 5"
        let result = OCRResult(fullText: text, lines: text.components(separatedBy: "\n").enumerated().map {
            OCRLine(text: $1, confidence: 0.95, boundingBox: CGRect(x: 0, y: 0.9 - Double($0) * 0.1, width: 1, height: 0.05))
        }, meanConfidence: 0.95)
        let candidates = EventExtractionCore.extract(from: result, locale: Locale(identifier: "en_US"), anchor: anchor)
        #expect(candidates.count == 1)
        #expect(candidates.first.map { calendar.dateComponents([.month, .day, .hour], from: $0.startDate) } == DateComponents(month: 10, day: 17, hour: 19))
        // A deadline-only flyer still yields its date.
        #expect(!EventExtractionCore.extract(from: OCRResult(fullText: "Applications\nDeadline October 3, 2026", lines: [
            OCRLine(text: "Applications", confidence: 0.95, boundingBox: CGRect(x: 0, y: 0.8, width: 1, height: 0.08)),
            OCRLine(text: "Deadline October 3, 2026", confidence: 0.95, boundingBox: CGRect(x: 0, y: 0.6, width: 1, height: 0.05))
        ], meanConfidence: 0.95), locale: Locale(identifier: "en_US"), anchor: anchor).isEmpty)
    }

    // MARK: - 6. False-Positive Filtering Tests

    @Test("Receipts, shipping notices, and pure timestamps are rejected as false positives")
    func testFalsePositiveFiltering() {
        let anchor = testAnchor

        // Grocery / restaurant receipt
        let receiptText = """
        CAFE GRATITUDE
        1x ESPRESSO $4.50
        1x AVOCADO TOAST $14.00
        SUBTOTAL: $18.50
        TAX: $1.75
        TOTAL AMOUNT: $20.25
        TIP: $4.00
        """
        #expect(DateInference.isFalsePositive(text: receiptText, anchor: anchor) == true)

        // Shipping notification
        let shippingText = """
        Your package was delivered to front porch!
        Tracking # 9400 1000 0000 0000 0000 00
        Carrier: USPS Tracking
        """
        #expect(DateInference.isFalsePositive(text: shippingText, anchor: anchor) == true)

        // Pure timestamp
        let timestampText = "10:45:00"
        #expect(DateInference.isFalsePositive(text: timestampText, anchor: anchor) == true)

        // Valid event flyer is NOT a false positive
        let flyerText = """
        ROOFTOP SUNSET PARTY
        FRIDAY JULY 18 2025
        DOORS OPEN 7:00 PM
        SKYBAR 8440 SUNSET BLVD
        """
        #expect(DateInference.isFalsePositive(text: flyerText, anchor: anchor) == false)
    }

    // MARK: - 7. Dedupe Key Stability and Normalization Tests

    @Test("Dedupe key is deterministic, normalized, and stable across casing and diacritics")
    func testDedupeKeyNormalization() {
        let date = Date(timeIntervalSince1970: 1750000000)

        let key1 = DateInference.computeDedupeKey(
            title: "The Neon Sunset Rooftop!",
            startDate: date,
            venueOrLocation: "Skybar Penthouse",
            assetIdentifier: "asset_01"
        )

        let key2 = DateInference.computeDedupeKey(
            title: "neon sunset rooftop",
            startDate: date,
            venueOrLocation: "skybar penthouse",
            assetIdentifier: "asset_01"
        )

        // Normalized titles with dropped stop-words ("the") should match exactly
        #expect(key1 == key2)
        #expect(key1.count == 16) // 16-character hex representation of FNV-1a 64-bit

        // Different dates produce different keys
        let differentDate = Date(timeIntervalSince1970: 1750086400)
        let keyDifferent = DateInference.computeDedupeKey(
            title: "The Neon Sunset Rooftop!",
            startDate: differentDate,
            venueOrLocation: "Skybar Penthouse",
            assetIdentifier: "asset_01"
        )
        #expect(key1 != keyDifferent)
    }
}
