import Foundation
import Testing
@testable import Pencild

@Suite("RelativeDateResolver Tests")
struct RelativeDateResolverTests {

    private func makeFixture() -> (calendar: Calendar, anchor: Date) {
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
        return (calendar, anchor)
    }

    // MARK: - Tonight Tests

    @Test("Resolves tonight with explicit 19:00 time")
    func testResolveTonight() {
        let (calendar, anchor) = makeFixture()

        let result = RelativeDateResolver.resolveTonight(in: "tonight", anchor: anchor, calendar: calendar)
        #expect(result != nil)
        #expect(result?.hasExplicitTime == true)

        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: result!.date)
        #expect(comps.year == 2026)
        #expect(comps.month == 10)
        #expect(comps.day == 14)
        #expect(comps.hour == 19)
        #expect(comps.minute == 0)

        // Case insensitivity via main entry point
        let mainResult = RelativeDateResolver.resolve(in: "Join us TONIGHT for drinks!", anchor: anchor, calendar: calendar)
        #expect(mainResult == result)
    }

    // MARK: - Today Tests

    @Test("Resolves today without explicit time")
    func testResolveToday() {
        let (calendar, anchor) = makeFixture()

        let result = RelativeDateResolver.resolveToday(in: "today", anchor: anchor)
        #expect(result != nil)
        #expect(result?.hasExplicitTime == false)
        #expect(result?.date == anchor)

        // Via main entry point
        let mainResult = RelativeDateResolver.resolve(in: "Happening Today at noon", anchor: anchor, calendar: calendar)
        #expect(mainResult?.date == anchor)
        #expect(mainResult?.hasExplicitTime == false)
    }

    // MARK: - Tomorrow / Tmrw Tests

    @Test("Resolves tomorrow and tmrw without explicit time")
    func testResolveTomorrow() {
        let (calendar, anchor) = makeFixture()

        let resultTomorrow = RelativeDateResolver.resolveTomorrow(in: "tomorrow", anchor: anchor, calendar: calendar)
        #expect(resultTomorrow != nil)
        #expect(resultTomorrow?.hasExplicitTime == false)
        let tmrwComps = calendar.dateComponents([.year, .month, .day], from: resultTomorrow!.date)
        #expect(tmrwComps.year == 2026)
        #expect(tmrwComps.month == 10)
        #expect(tmrwComps.day == 15)

        let resultTmrw = RelativeDateResolver.resolveTomorrow(in: "tmrw", anchor: anchor, calendar: calendar)
        #expect(resultTmrw != nil)
        #expect(resultTmrw?.date == resultTomorrow?.date)

        let mainResult = RelativeDateResolver.resolve(in: "See you TMRW morning!", anchor: anchor, calendar: calendar)
        #expect(mainResult?.date == resultTomorrow?.date)
    }

    // MARK: - In N Days Tests

    @Test("Resolves in N days with proper day addition")
    func testResolveInDays() {
        let (calendar, anchor) = makeFixture()

        let result = RelativeDateResolver.resolveInDays(in: "in 5 days", anchor: anchor, calendar: calendar)
        #expect(result != nil)
        #expect(result?.hasExplicitTime == false)
        let comps = calendar.dateComponents([.year, .month, .day], from: result!.date)
        #expect(comps.year == 2026)
        #expect(comps.month == 10)
        #expect(comps.day == 19)

        // Singular day
        let singleDayResult = RelativeDateResolver.resolveInDays(in: "in 1 day", anchor: anchor, calendar: calendar)
        #expect(singleDayResult != nil)
        let singleComps = calendar.dateComponents([.day], from: singleDayResult!.date)
        #expect(singleComps.day == 15)

        let mainResult = RelativeDateResolver.resolve(in: "Release party in 3 days", anchor: anchor, calendar: calendar)
        #expect(mainResult != nil)
        let mainComps = calendar.dateComponents([.day], from: mainResult!.date)
        #expect(mainComps.day == 17)
    }

    // MARK: - In N Weeks Tests

    @Test("Resolves in N weeks with proper week addition")
    func testResolveInWeeks() {
        let (calendar, anchor) = makeFixture()

        let result = RelativeDateResolver.resolveInWeeks(in: "in 2 weeks", anchor: anchor, calendar: calendar)
        #expect(result != nil)
        #expect(result?.hasExplicitTime == false)
        let comps = calendar.dateComponents([.year, .month, .day], from: result!.date)
        #expect(comps.year == 2026)
        #expect(comps.month == 10)
        #expect(comps.day == 28)

        // Singular week
        let singleWeekResult = RelativeDateResolver.resolveInWeeks(in: "in 1 week", anchor: anchor, calendar: calendar)
        #expect(singleWeekResult != nil)
        let singleComps = calendar.dateComponents([.day], from: singleWeekResult!.date)
        #expect(singleComps.day == 21)

        let mainResult = RelativeDateResolver.resolve(in: "Reunion in 2 weeks at the park", anchor: anchor, calendar: calendar)
        #expect(mainResult?.date == result?.date)
    }

    // MARK: - Relative Weekday Tests

    @Test("Resolves this and coming weekdays correctly")
    func testResolveThisAndComingWeekday() {
        let (calendar, anchor) = makeFixture() // Wednesday Oct 14, 2026

        // "this friday" -> Oct 16 (2 days ahead)
        let thisFri = RelativeDateResolver.resolveRelativeWeekday(in: "this friday", anchor: anchor, calendar: calendar)
        #expect(thisFri != nil)
        #expect(thisFri?.hasExplicitTime == false)
        let thisFriComps = calendar.dateComponents([.day], from: thisFri!.date)
        #expect(thisFriComps.day == 16)

        // "coming friday" -> Oct 16
        let comingFri = RelativeDateResolver.resolveRelativeWeekday(in: "coming friday", anchor: anchor, calendar: calendar)
        #expect(comingFri?.date == thisFri?.date)

        // "this wednesday" on a Wednesday -> 7 days ahead (next occurrence)
        let thisWed = RelativeDateResolver.resolveRelativeWeekday(in: "this wednesday", anchor: anchor, calendar: calendar)
        #expect(thisWed != nil)
        let thisWedComps = calendar.dateComponents([.day], from: thisWed!.date)
        #expect(thisWedComps.day == 21)
    }

    @Test("Resolves next weekday strictly as the following week")
    func testResolveNextWeekday() {
        let (calendar, anchor) = makeFixture() // Wednesday Oct 14, 2026

        // "next friday" -> Friday is 2 days ahead + 7 days = 9 days ahead -> Oct 23
        let nextFri = RelativeDateResolver.resolveRelativeWeekday(in: "next friday", anchor: anchor, calendar: calendar)
        #expect(nextFri != nil)
        let nextFriComps = calendar.dateComponents([.day], from: nextFri!.date)
        #expect(nextFriComps.day == 23)

        // Abbreviated weekday: "next fri"
        let nextFriAbbr = RelativeDateResolver.resolveRelativeWeekday(in: "next fri", anchor: anchor, calendar: calendar)
        #expect(nextFriAbbr?.date == nextFri?.date)
    }

    // MARK: - Unmatched / Edge Cases

    @Test("Returns nil when no relative phrase is present")
    func testUnmatchedPhrases() {
        let (calendar, anchor) = makeFixture()

        #expect(RelativeDateResolver.resolve(in: "Regular meeting on Dec 25", anchor: anchor, calendar: calendar) == nil)
        #expect(RelativeDateResolver.resolve(in: "Random note about yesterday", anchor: anchor, calendar: calendar) == nil)
        #expect(RelativeDateResolver.resolve(in: "", anchor: anchor, calendar: calendar) == nil)
    }
}
