import EventKit
import Foundation
import StoreKit
import SwiftData
import Testing
import UserNotifications
@testable import Pencild

private final class ManualTestCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _createdTitles: [String] = []
    var createdTitles: [String] { lock.withLock { _createdTitles } }
    func requestEventAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchWritableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }
    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        lock.withLock { _createdTitles.append(candidate.title) }
        return "manual-calendar-id-\(candidate.id)"
    }
    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        externalIdentifier
    }
    func deleteEvent(externalIdentifier: String) throws {}
}

private final class ManualTestReminderService: ReminderServiceProtocol, @unchecked Sendable {
    func requestReminderAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchReminderLists() -> [EKCalendar] { [] }
    func defaultReminderList() -> EKCalendar? { nil }
    func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String { "manual-reminder-id" }
    func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        externalIdentifier
    }
    func deleteReminder(externalIdentifier: String) throws {}
    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String { "manual-deadline-id" }
}

private final class ManualTestNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        ["manual-notification-id"]
    }
    func removePendingNotifications(identifiers: [String]) {}
    func removeAllPendingNotifications() {}
    func setupNotificationCategories() {}
}

@MainActor
private final class ManualTestSubscriptionService: SubscriptionServiceProtocol {
    var entitlementSnapshot = EntitlementSnapshot.verified(.starter, provenance: .none)
    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }
    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

@Suite("Enter Manually")
@MainActor
struct ManualEntryTests {
    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services(calendar: ManualTestCalendarService) -> ServiceContainer {
        ServiceContainer(
            photoLibrary: PhotoLibraryService(),
            ocr: OCRService(),
            eventExtraction: EventExtractionService(),
            calendar: calendar,
            reminders: ManualTestReminderService(),
            notifications: ManualTestNotificationService(),
            subscription: ManualTestSubscriptionService(),
            understanding: EventUnderstandingPipeline.rulesOnly(calendar: testCalendar),
            scanUsage: .forTesting()
        )
    }

    @Test("A manual event starts blank at the next hour and is marked as manual")
    func makeCandidate() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let now = try #require(testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 4, hour: 9, minute: 20)))
        let candidate = try ManualEventFactory.makeCandidate(in: context, now: now, calendar: testCalendar)

        #expect(candidate.isManualEntry)
        #expect(candidate.title.isEmpty)
        #expect(candidate.startDate == testCalendar.date(from: DateComponents(year: 2030, month: 5, day: 4, hour: 10)))
        #expect(candidate.confidenceTier == .high)
        #expect(try context.fetch(FetchDescriptor<EventCandidate>()).count == 1)
    }

    @Test("A scan prefill keeps the scan: not manual, low confidence, carries the text")
    func scanPrefill() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let candidate = try ManualEventFactory.makeCandidate(
            in: context,
            prefill: .init(title: "Spring Fair", rawText: "Spring Fair\nCentral Park")
        )
        #expect(!candidate.isManualEntry)
        #expect(candidate.title == "Spring Fair")
        #expect(candidate.rawTextSnippet.contains("Central Park"))
        #expect(candidate.confidenceTier == .low)
        #expect(candidate.needsReview)
        ManualEventFactory.discardIfUnused(candidate, in: context)
        #expect(try context.fetch(FetchDescriptor<EventCandidate>()).count == 1)
    }

    @Test("Save Draft on a never-saved event files it as a draft, not as saved")
    func draftOfNewEventIsDraft() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let candidate = try ManualEventFactory.makeCandidate(
            in: context,
            prefill: .init(title: "Spring Fair", rawText: "Spring Fair")
        )
        let viewModel = EventReviewViewModel(candidate: candidate, services: services(calendar: ManualTestCalendarService()))
        _ = viewModel.saveDraft(modelContext: context)
        #expect(candidate.savedEvent?.status == .draft)
        #expect(candidate.needsReview)
    }

    @Test("An unsaved manual event doesn't need review; a drafted one does")
    func needsReview() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let candidate = try ManualEventFactory.makeCandidate(in: context)
        #expect(!candidate.needsReview)
        let viewModel = EventReviewViewModel(candidate: candidate, services: services(calendar: ManualTestCalendarService()))
        viewModel.title = "Dentist"
        _ = viewModel.saveDraft(modelContext: context)
        #expect(candidate.needsReview)
    }

    @Test("Closing an untouched manual event removes it; a draft is kept")
    func discardIfUnused() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let untouched = try ManualEventFactory.makeCandidate(in: context)
        ManualEventFactory.discardIfUnused(untouched, in: context)
        #expect(try context.fetch(FetchDescriptor<EventCandidate>()).isEmpty)

        let drafted = try ManualEventFactory.makeCandidate(in: context)
        let viewModel = EventReviewViewModel(candidate: drafted, services: services(calendar: ManualTestCalendarService()))
        viewModel.title = "Dentist"
        _ = viewModel.saveDraft(modelContext: context)
        ManualEventFactory.discardIfUnused(drafted, in: context)
        #expect(try context.fetch(FetchDescriptor<EventCandidate>()).count == 1)
    }

    @Test("A manual event needs a title before it saves to Calendar")
    func titleRequired() async throws {
        let container = try modelContainer()
        let context = container.mainContext
        let calendar = ManualTestCalendarService()
        let candidate = try ManualEventFactory.makeCandidate(in: context)
        let viewModel = EventReviewViewModel(candidate: candidate, services: services(calendar: calendar))

        #expect(viewModel.isManualEntry)
        #expect(viewModel.needsTitle)
        let blocked = await viewModel.commitEvent(modelContext: context)
        guard case .failure = blocked else { Issue.record("Expected a failure without a title"); return }
        #expect(calendar.createdTitles.isEmpty)

        viewModel.title = "Team lunch"
        #expect(!viewModel.needsTitle)
        _ = await viewModel.commitEvent(modelContext: context)
        #expect(calendar.createdTitles == ["Team lunch"])
    }
}
