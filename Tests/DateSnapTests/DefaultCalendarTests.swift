import EventKit
import Foundation
import Testing
@testable import DateSnap

@Suite("Default calendar store")
struct DefaultCalendarStoreTests {
    private func store() -> DefaultCalendarStore {
        DefaultCalendarStore(defaultsSuiteName: "datesnap.tests.defaultCalendar.\(UUID().uuidString)")
    }

    @Test("Unset store reads nil and the picker shows the iOS default")
    func unsetByDefault() {
        let store = store()
        #expect(store.defaultCalendarIdentifier() == nil)
        #expect(store.defaultCalendarTitle() == nil)
    }

    @Test("Set, replace and clear round-trips through the suite")
    func setReplaceClear() {
        let store = store()

        store.setDefaultCalendarIdentifier("cal-home", title: "Home")
        #expect(store.defaultCalendarIdentifier() == "cal-home")
        #expect(store.defaultCalendarTitle() == "Home")

        store.setDefaultCalendarIdentifier("cal-work", title: "Work")
        #expect(store.defaultCalendarIdentifier() == "cal-work")
        #expect(store.defaultCalendarTitle() == "Work")

        store.reset()
        #expect(store.defaultCalendarIdentifier() == nil)
        #expect(store.defaultCalendarTitle() == nil)
    }

    @Test("Setting nil clears a previous choice")
    func setNilClears() {
        let store = store()
        store.setDefaultCalendarIdentifier("cal-home", title: "Home")
        store.setDefaultCalendarIdentifier(nil)
        #expect(store.defaultCalendarIdentifier() == nil)
    }
}

@Suite("Destination calendar resolution")
struct DestinationCalendarResolverTests {

    private struct Option: DestinationCalendarResolver.Option {
        let id: String
        let title: String
        var calendarIdentifier: String { id }
    }

    private let home = Option(id: "cal-home", title: "Home")
    private let work = Option(id: "cal-work", title: "Work")
    private let shared = Option(id: "cal-shared", title: "Shared")
    private var options: [Option] { [work, home, shared] } // alphabetical-ish, NOT user default first

    @Test("User default beats the list order and the iOS default")
    func userDefaultWins() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: "cal-home",
            recommendedIdentifier: "cal-work",
            systemDefault: work
        )
        #expect(picked?.title == "Home")
    }

    @Test("The calendar already saved on the event wins over everything (editing keeps destination)")
    func savedTitleWins() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: "Shared",
            userDefaultIdentifier: "cal-home",
            recommendedIdentifier: "cal-work",
            systemDefault: home
        )
        #expect(picked?.title == "Shared")
    }

    @Test("Without a user default, the learned per-category recommendation applies")
    func learnedRecommendationApplies() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: nil,
            recommendedIdentifier: "cal-work",
            systemDefault: home
        )
        #expect(picked?.title == "Work")
    }

    @Test("Without any saved choice, the iOS system default applies")
    func systemDefaultApplies() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: nil,
            recommendedIdentifier: nil,
            systemDefault: home
        )
        #expect(picked?.title == "Home")
    }

    @Test("A stale saved identifier (deleted calendar) falls through to the iOS default")
    func staleUserDefaultFallsThrough() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: "cal-deleted",
            recommendedIdentifier: nil,
            systemDefault: shared
        )
        #expect(picked?.title == "Shared")
    }

    @Test("With nothing set, the first writable calendar is the deterministic fallback")
    func firstWritableFallback() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: nil,
            recommendedIdentifier: nil,
            systemDefault: nil
        )
        #expect(picked?.title == "Work")
    }

    @Test("An option whose identifier matches nothing is never selected on its own")
    func unmatchedIdentifierIsSkipped() {
        let picked = DestinationCalendarResolver.select(
            options,
            savedTitle: nil,
            userDefaultIdentifier: "cal-nothing",
            recommendedIdentifier: nil,
            systemDefault: home
        )
        #expect(picked?.title == "Home")
    }
}
