import EventKit
import Foundation
import Photos
import StoreKit
import SwiftData
import Testing
import UIKit
@testable import DateSnap

// Self-contained fakes (MockDataCleanupTests keeps its own private copies).
private enum BatchInjectedFailure: Error, LocalizedError {
    case calendar
    var errorDescription: String? { "Injected batch Calendar failure" }
}

private struct BatchOCRUnavailable: Error {}

private final class BatchTestCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    let createError: Error?
    private let lock = NSLock()
    private var _createdTitles: [String] = []
    init(createError: Error? = nil) { self.createError = createError }
    /// Titles of events actually written to Calendar, in creation order.
    var createdTitles: [String] { lock.withLock { _createdTitles } }
    func requestEventAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchWritableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }
    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        if let createError { throw createError }
        lock.withLock { _createdTitles.append(candidate.title) }
        return "batch-calendar-id-\(candidate.id)"
    }
    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        externalIdentifier
    }
    func deleteEvent(externalIdentifier: String) throws {}
}

private final class BatchTestReminderService: ReminderServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _createdTitles: [String] = []
    /// Titles of events actually written to Reminders, in creation order.
    var createdTitles: [String] { lock.withLock { _createdTitles } }
    func requestReminderAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchReminderLists() -> [EKCalendar] { [] }
    func defaultReminderList() -> EKCalendar? { nil }
    func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        lock.withLock { _createdTitles.append(candidate.title) }
        return "batch-reminder-id"
    }
    func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        externalIdentifier
    }
    func deleteReminder(externalIdentifier: String) throws {}
    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String {
        "batch-deadline-id"
    }
}

private final class BatchTestNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        ["batch-notification-id"]
    }
    func removePendingNotifications(identifiers: [String]) {}
    func removeAllPendingNotifications() {}
    func setupNotificationCategories() {}
}

@MainActor
private final class BatchTestSubscriptionService: SubscriptionServiceProtocol {
    var entitlementSnapshot = EntitlementSnapshot.verified(.starter, provenance: .none)
    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }
    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

@Suite("Batch scan and review")
@MainActor
struct BatchScanTests {

    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services(
        calendar: BatchTestCalendarService = BatchTestCalendarService(),
        reminders: BatchTestReminderService = BatchTestReminderService()
    ) -> ServiceContainer {
        ServiceContainer(
            photoLibrary: TestBatchPhotoLibrary(),
            ocr: OCRService(),
            eventExtraction: EventExtractionService(),
            calendar: calendar,
            reminders: reminders,
            notifications: BatchTestNotificationService(),
            subscription: BatchTestSubscriptionService(),
            understanding: EventUnderstandingPipeline.rulesOnly(calendar: testCalendar)
        )
    }

    private func makeItem(
        title: String,
        calendar: BatchTestCalendarService = BatchTestCalendarService(),
        reminders: BatchTestReminderService = BatchTestReminderService()
    ) -> BatchEventItem {
        let candidate = EventCandidate(title: title, startDate: testFutureDate)
        return BatchEventItem(
            candidate: candidate,
            screenshotID: UUID(),
            screenshotLabel: BatchScanViewModel.label(forIndex: 1),
            screenshotImage: nil,
            services: services(calendar: calendar, reminders: reminders)
        )
    }

    // MARK: Labels & item stages

    @Test("Batch labels are one-based")
    func labelsAreOneBased() {
        #expect(BatchScanViewModel.label(forIndex: 1) == "Screenshot 1")
        #expect(BatchScanViewModel.label(forIndex: 5) == "Screenshot 5")
    }

    @Test("Found items succeed and carry candidates; empty results report noDates")
    func itemStages() {
        let item = BatchScanItem(label: BatchScanViewModel.label(forIndex: 1))
        #expect(!item.isResolved)
        #expect(!item.isSuccess)

        item.begin()
        #expect(!item.isResolved)

        let candidate = EventCandidate(title: "Found event", startDate: testFutureDate)
        item.complete(candidates: [candidate])
        #expect(item.isResolved)
        #expect(item.isSuccess)
        #expect(item.candidates.count == 1)

        let empty = BatchScanItem(label: BatchScanViewModel.label(forIndex: 2))
        empty.complete(candidates: [])
        #expect(empty.isResolved)
        #expect(!empty.isSuccess)
    }

    @Test("Display image is downsampled from oversized sources and kept otherwise")
    func displayImageDownsampling() {
        let item = BatchScanItem(label: BatchScanViewModel.label(forIndex: 1))
        let small = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 80)).image { _ in }
        item.setDisplayImage(small)
        #expect(item.image?.size.width == 100)

        let huge = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 1000)).image { _ in }
        item.setDisplayImage(huge)
        #expect(item.image != nil)
        #expect(item.image!.size.width <= 1281)
    }

    // MARK: Batch scan pipeline

    @Test("A failed source fails only its own item; other items are unaffected")
    func failedSourceIsolates() async {
        let scanner = BatchScanViewModel(services: services())
        await scanner.scan([.failed(reason: "Could not load the screenshot")], modelContext: nil)

        #expect(scanner.items.count == 1)
        #expect(!scanner.isProcessing)
        #expect(scanner.currentLabel == "")
        if case .failed(let message) = scanner.items[0].stage {
            #expect(message.contains("Could not load"))
        } else {
            Issue.record("Expected the item to fail")
        }
    }

    @Test("Mixed batch keeps outcomes per screenshot in order")
    func mixedBatchOrdering() async {
        let scanner = BatchScanViewModel(services: services())
        await scanner.scan(
            [.failed(reason: "Load failed"), .loaded(id: "unscannable", image: solidImage())],
            modelContext: nil
        )

        #expect(scanner.items.count == 2)
        if case .failed = scanner.items[0].stage {} else {
            Issue.record("Expected first item to fail")
        }
        // A blank image produces no dates but must not poison the second item.
        if case .noDates = scanner.items[1].stage {} else {
            Issue.record("Expected second item to finish with no dates")
        }
        #expect(scanner.foundItems.isEmpty)
        #expect(scanner.totalEventCount == 0)
    }

    @Test("An image with an event is found and counted")
    func foundEventCounting() async {
        // Reuse the bundled sample flyer rendering: the same pipeline the single flow uses.
        let image = SampleFlyer.render()
        let scanner = BatchScanViewModel(services: services())
        await scanner.scan([.loaded(id: "sample-flyer", image: image)], modelContext: nil)

        #expect(scanner.items.count == 1)
        #expect(scanner.foundItems.count == 1)
        #expect(scanner.totalEventCount >= 1)
    }

    @Test("An empty batch scan does nothing")
    func emptyBatchIsNoop() async {
        let scanner = BatchScanViewModel(services: services())
        await scanner.scan([], modelContext: nil)
        #expect(scanner.items.isEmpty)
        #expect(!scanner.isProcessing)
    }

    @Test("Deduplication inside a batch: the same asset scanned twice collapses to stored candidates")
    func duplicateAssetCollapses() async throws {
        let container = try modelContainer()
        let image = SampleFlyer.render()
        let scanner = BatchScanViewModel(services: services())
        await scanner.scan(
            [.loaded(id: "same-asset", image: image), .loaded(id: "same-asset", image: image)],
            modelContext: container.mainContext
        )

        let stored = try container.mainContext.fetch(FetchDescriptor<EventCandidate>())
        #expect(stored.count == 1)
        #expect(scanner.foundItems.count == 2)
        #expect(scanner.totalEventCount == 2)
    }

    // MARK: Batch review session

    @Test("Save All commits each event; one failure does not block the rest")
    func saveAllPerEventIsolation() async throws {
        let container = try modelContainer()
        let good = makeItem(title: "Good Event")
        let bad = makeItem(title: "Bad Event", calendar: BatchTestCalendarService(createError: BatchInjectedFailure.calendar))

        let session = BatchReviewSession(events: [good, bad])
        let summary = await session.saveAll(modelContext: container.mainContext)

        #expect(summary.savedCount == 1)
        #expect(summary.failedMessages.count == 1)
        #expect(summary.failedMessages[0].contains("Bad Event"))
        #expect(good.status == .saved)
        if case .failed = bad.status {} else {
            Issue.record("Expected the failing event to record its failure")
        }

        // The failed event stays actionable so the user can retry it.
        #expect(bad.isActionable)
        #expect(!good.isActionable)
    }

    @Test("Save All writes every kept event to both Apple Calendar and Reminders in one action")
    func saveAllWritesCalendarAndRemindersForEachEvent() async throws {
        let container = try modelContainer()
        let calendar = BatchTestCalendarService()
        let reminders = BatchTestReminderService()
        let first = makeItem(title: "Concert Night", calendar: calendar, reminders: reminders)
        let second = makeItem(title: "Dinner Meetup", calendar: calendar, reminders: reminders)

        let session = BatchReviewSession(events: [first, second])
        let summary = await session.saveAll(modelContext: container.mainContext)

        #expect(summary.savedCount == 2)
        #expect(summary.isAllSaved)
        // Each item runs the same single-item commit path (EventReviewViewModel.commitEvent),
        // so one Calendar event and one Reminders entry are created per selected event.
        #expect(calendar.createdTitles == ["Concert Night", "Dinner Meetup"])
        #expect(reminders.createdTitles == ["Concert Night", "Dinner Meetup"])
        #expect(first.status == .saved)
        #expect(second.status == .saved)

        // Persisted end state: each event's record carries both external IDs, not
        // just an in-memory status — this is what the user would see in Apple apps.
        let saved = try container.mainContext.fetch(FetchDescriptor<SavedEvent>())
        #expect(saved.count == 2)
        #expect(Set(saved.compactMap { $0.candidate?.title }) == ["Concert Night", "Dinner Meetup"])
        #expect(saved.allSatisfy { $0.status == .saved })
        #expect(saved.allSatisfy { $0.externalCalendarEventId?.hasPrefix("batch-calendar-id-") == true })
        #expect(saved.allSatisfy { $0.externalReminderIds == ["batch-reminder-id"] })
        #expect(saved.allSatisfy { $0.scheduledNotificationIds == ["batch-notification-id"] })
    }

    @Test("Discard removes an unsaved event from the session and persists deletion")
    func discardRemovesEvent() async throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Discard me", startDate: testFutureDate)
        let item = BatchEventItem(
            candidate: candidate,
            screenshotID: UUID(),
            screenshotLabel: "Screenshot 1",
            screenshotImage: nil,
            services: services()
        )
        container.mainContext.insert(candidate)
        try container.mainContext.save()

        let session = BatchReviewSession(events: [item])
        let removed = session.discard(item, modelContext: container.mainContext)

        #expect(removed)
        #expect(session.events.isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<EventCandidate>()).isEmpty)
    }

    @Test("A saved event can no longer be discarded from the batch")
    func discardBlockedAfterSave() async throws {
        let container = try modelContainer()
        let item = makeItem(title: "Already saved")

        let session = BatchReviewSession(events: [item])
        _ = await session.saveAll(modelContext: container.mainContext)
        #expect(item.status == .saved)

        let removed = session.discard(item, modelContext: container.mainContext)
        #expect(!removed)
        #expect(session.events.count == 1)
    }

    @Test("Retry after a failure re-attempts only failed events, not saved ones")
    func retryAfterFailure() async throws {
        let container = try modelContainer()
        let good = makeItem(title: "Retry Good")
        let bad = makeItem(title: "Retry Bad", calendar: BatchTestCalendarService(createError: BatchInjectedFailure.calendar))

        let session = BatchReviewSession(events: [good, bad])
        let first = await session.saveAll(modelContext: container.mainContext)
        #expect(first.savedCount == 1)

        // Second pass re-runs only the failed event (it fails again deterministically).
        let second = await session.saveAll(modelContext: container.mainContext)
        #expect(second.savedCount == 0)
        #expect(second.failedMessages.count == 1)
        #expect(good.status == .saved)
    }

    private func solidImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480)).image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        }
    }
}

private final class TestBatchPhotoLibrary: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus { .denied }
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .denied }
    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] { [] }
    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage {
        throw BatchOCRUnavailable()
    }
    func observeLibraryChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}
