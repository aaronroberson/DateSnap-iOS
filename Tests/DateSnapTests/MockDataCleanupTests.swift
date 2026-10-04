import EventKit
import Foundation
import Photos
import StoreKit
import SwiftData
import Testing
import UIKit
@testable import DateSnap

private enum InjectedServiceFailure: Error, LocalizedError {
    case calendar
    case reminder
    case notification
    case ocr
    case offline
    case persistence

    var errorDescription: String? {
        switch self {
        case .calendar: "Injected Calendar failure"
        case .reminder: "Injected Reminders failure"
        case .notification: "Injected notification failure"
        case .ocr: "Injected OCR failure"
        case .offline: "StoreKit is unavailable offline"
        case .persistence: "Injected SwiftData failure"
        }
    }
}

@Suite("Sample and failure paths")
@MainActor
struct MockDataCleanupTests {
    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services(
        photo: TestPhotoLibrary = TestPhotoLibrary(),
        ocr: OCRServiceProtocol = OCRService(),
        calendar: TestCalendarService = TestCalendarService(),
        reminders: TestReminderService = TestReminderService(),
        notifications: TestNotificationService = TestNotificationService(),
        subscription: OfflineSubscriptionService = OfflineSubscriptionService()
    ) -> ServiceContainer {
        ServiceContainer(
            photoLibrary: photo,
            ocr: ocr,
            eventExtraction: EventExtractionService(),
            calendar: calendar,
            reminders: reminders,
            notifications: notifications,
            subscription: subscription,
            understanding: EventUnderstandingPipeline.rulesOnly()
        )
    }

    @Test("SampleFlyer scans through Vision and rules without Photos or StoreKit")
    func sampleFlyerUsesProductionLocalPipeline() async throws {
        let photos = TestPhotoLibrary(status: .denied)
        let store = OfflineSubscriptionService()
        let services = services(photo: photos, subscription: store)
        let container = try modelContainer()
        let scanner = ScanViewModel(services: services)

        await scanner.scanSampleFlyer(modelContext: container.mainContext)

        let candidates = try container.mainContext.fetch(FetchDescriptor<EventCandidate>())
        #expect(!scanner.rawOcrText.isEmpty)
        #expect(scanner.rawOcrText.localizedCaseInsensitiveContains("NEON SUNSET"))
        #expect(scanner.lastResult?.route == .rulesOnly)
        #expect(!candidates.isEmpty)
        #expect(candidates.contains { $0.startDate > Date() })
        #expect(photos.requestCount == 0)
        #expect(photos.fetchCount == 0)
        #expect(store.fetchCount == 0)
    }

    @Test("Document import enforces the current verified Premium entitlement at its boundary")
    func documentImportAuthorization() async {
        for snapshot in [
            EntitlementSnapshot.verified(.starter, provenance: .none),
            EntitlementSnapshot.verified(.plus, provenance: .none),
            EntitlementSnapshot(tier: .premium, state: .checking, provenance: .none),
            EntitlementSnapshot(tier: .premium, state: .unverified, provenance: .none),
            EntitlementSnapshot(tier: .premium, state: .unavailable, provenance: .none),
        ] {
            let store = OfflineSubscriptionService(snapshot: snapshot)
            let scanner = ScanViewModel(services: services(subscription: store))
            let decision = await scanner.scanDocument(at: URL(fileURLWithPath: "/not-readable.pdf"))

            #expect(decision != .allowed)
            #expect(scanner.isProcessing == false)
        }

        let premium = OfflineSubscriptionService(snapshot: .verified(.premium, provenance: .none))
        let scanner = ScanViewModel(services: services(subscription: premium))
        let decision = await scanner.scanDocument(at: URL(fileURLWithPath: "/not-readable.pdf"))
        #expect(decision == .allowed)
    }

    @Test("OCR errors stop a scan and reach the scan state")
    func scanSurfacesOCRError() async {
        let scanner = ScanViewModel(services: services(ocr: FailingOCRService()))
        await scanner.scanSampleFlyer()
        if case .failed(let message) = scanner.stage {
            #expect(message.contains("Injected OCR failure"))
        } else {
            Issue.record("Expected the scan to fail when OCR fails")
        }
    }

    @Test("Calendar failure prevents a saved success result")
    func calendarFailureDoesNotCommit() async throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Calendar failure", startDate: Date().addingTimeInterval(86_400))
        let review = EventReviewViewModel(candidate: candidate, services: services(calendar: TestCalendarService(createError: .calendar)))

        let result = await review.commitEvent(modelContext: container.mainContext)

        if case .failure(let error) = result {
            #expect(error.localizedDescription.contains("Injected Calendar failure"))
        } else {
            Issue.record("Expected Calendar failure to be returned")
        }
        #expect(!review.isSavedSuccessfully)
        #expect(try container.mainContext.fetch(FetchDescriptor<SavedEvent>()).isEmpty)
    }

    @Test("Reminder and notification failures are reported after local event persistence")
    func reminderAndNotificationFailuresReturnPartial() async throws {
        let container = try modelContainer()
        let candidate = EventCandidate(
            title: "Reminder failure",
            startDate: Date().addingTimeInterval(86_400)
        )
        candidate.rsvpDeadline = Date().addingTimeInterval(3_600)
        let review = EventReviewViewModel(
            candidate: candidate,
            services: services(
                reminders: TestReminderService(createError: .reminder, deadlineError: .reminder),
                notifications: TestNotificationService(scheduleError: .notification),
                subscription: OfflineSubscriptionService(snapshot: .verified(.premium, provenance: .none))
            )
        )
        review.deadlineReminderEnabled = true

        let result = await review.commitEvent(modelContext: container.mainContext)

        if case .partial(let issues) = result {
            #expect(issues.contains { $0.contains("Reminders") })
            #expect(issues.contains { $0.contains("RSVP deadline") })
            #expect(issues.contains { $0.contains("Local notifications") })
        } else {
            Issue.record("Expected partial success when event persistence succeeds but reminder operations fail")
        }
        #expect(candidate.savedEvent != nil)
        #expect(!review.isSavedSuccessfully)
    }

    @Test("Deadline reminder side effects require verified Premium at commit time")
    func deadlineReminderAuthorization() async throws {
        for tier in SubscriptionTier.allCases {
            let container = try modelContainer()
            let candidate = EventCandidate(title: "Tier \(tier.rawValue)", startDate: Date().addingTimeInterval(86_400))
            candidate.rsvpDeadline = Date().addingTimeInterval(7_200)
            let reminders = TestReminderService()
            let store = OfflineSubscriptionService(snapshot: .verified(tier, provenance: .none))
            let review = EventReviewViewModel(
                candidate: candidate,
                services: services(reminders: reminders, subscription: store)
            )
            review.deadlineReminderEnabled = true

            _ = await review.commitEvent(modelContext: container.mainContext)

            #expect(reminders.deadlineCreateCount == (tier == .premium ? 1 : 0))
            #expect((review.featureAccessDenial == nil) == (tier == .premium))
        }
    }

    @Test("Downgrading while editing prevents the deadline reminder side effect")
    func deadlineReminderDowngradeDuringEdit() async throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Downgraded", startDate: Date().addingTimeInterval(86_400))
        candidate.rsvpDeadline = Date().addingTimeInterval(7_200)
        let reminders = TestReminderService()
        let store = OfflineSubscriptionService(snapshot: .verified(.premium, provenance: .none))
        let review = EventReviewViewModel(
            candidate: candidate,
            services: services(reminders: reminders, subscription: store)
        )
        review.deadlineReminderEnabled = true
        store.entitlementSnapshot = .verified(.plus, provenance: .transactionUpdate)

        _ = await review.commitEvent(modelContext: container.mainContext)

        #expect(reminders.deadlineCreateCount == 0)
        #expect(review.featureAccessDenial == .requiresTier(.premium))
    }

    @Test("SwiftData save failures are returned from event and privacy mutations")
    func persistenceFailuresAreSurfaced() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let candidate = EventCandidate(title: "Persistence failure", startDate: Date().addingTimeInterval(86_400))
        let saved = SavedEvent(candidate: candidate)
        context.insert(candidate)
        context.insert(saved)
        context.insert(ScannedAsset(assetIdentifier: "scan", rawOcrText: "event text"))
        try context.save()

        let actions = SavedEventActions(
            services: services(),
            modelContext: context,
            saveOperation: { throw InjectedServiceFailure.persistence }
        )
        let statusResult = actions.setStatus(.archived, for: saved)
        let cacheResult = actions.clearScanCache()
        let eraseResult = actions.eraseAllLocalData()

        #expect(statusResult == .failure(MutationFailure(InjectedServiceFailure.persistence)))
        #expect(cacheResult == .failure(MutationFailure(message: "Could not clear the scan cache: Injected SwiftData failure")))
        #expect(eraseResult == .failure(MutationFailure(message: "Could not erase local DateSnap data: Injected SwiftData failure")))
    }

    @Test("Failed Calendar and Reminder cleanup retains the DateSnap record and identifiers")
    func externalCleanupFailureIsPartial() throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Keep cleanup record", startDate: Date().addingTimeInterval(86_400))
        let saved = SavedEvent(
            externalCalendarEventId: "calendar-id",
            externalReminderIds: ["reminder-id"],
            scheduledNotificationIds: ["notification-id"],
            candidate: candidate
        )
        saved.deadlineReminderId = "deadline-id"
        container.mainContext.insert(candidate)
        container.mainContext.insert(saved)
        try container.mainContext.save()
        let actions = SavedEventActions(
            services: services(
                calendar: TestCalendarService(deleteError: .calendar),
                reminders: TestReminderService(deleteError: .reminder)
            ),
            modelContext: container.mainContext
        )

        let result = actions.delete(saved, removeFromCalendar: true)

        if case .partial(let issues) = result {
            #expect(issues.contains { $0.contains("Calendar") })
            #expect(issues.contains { $0.contains("Reminders") })
        } else {
            Issue.record("Expected partial completion when Apple event cleanup fails")
        }
        #expect(saved.externalCalendarEventId == "calendar-id")
        #expect(saved.externalReminderIds == ["reminder-id"])
        #expect(saved.deadlineReminderId == "deadline-id")
        #expect(try container.mainContext.fetch(FetchDescriptor<SavedEvent>()).count == 1)
    }

    @Test("Reminder preview uses the configured default offsets")
    func reminderPreviewUsesDefaultOffsets() {
        let eventStart = Date(timeIntervalSince1970: 1_800_000_000)
        let previewDates = ReminderOffset.defaultStaggered.map {
            $0.triggerDate(forEventStart: eventStart, isAllDay: false)
        }
        #expect(previewDates.count == 2)
        #expect(abs(previewDates[0].timeIntervalSince(eventStart) + 86_400) < 1)
        #expect(abs(previewDates[1].timeIntervalSince(eventStart) + 7_200) < 1)
    }
}

private final class TestPhotoLibrary: PhotoLibraryServiceProtocol, @unchecked Sendable {
    let status: PHAuthorizationStatus
    private(set) var requestCount = 0
    private(set) var fetchCount = 0

    init(status: PHAuthorizationStatus = .denied) {
        self.status = status
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        requestCount += 1
        return status
    }

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { status }

    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] {
        fetchCount += 1
        return []
    }

    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage {
        throw InjectedServiceFailure.ocr
    }

    func observeLibraryChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

private struct FailingOCRService: OCRServiceProtocol {
    func recognizeText(in image: UIImage) async throws -> (fullText: String, confidence: Float) {
        throw InjectedServiceFailure.ocr
    }

    func recognizeLines(in image: UIImage, confidenceFloor: Float) async throws -> OCRResult {
        throw InjectedServiceFailure.ocr
    }
}

private final class TestCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    let createError: InjectedServiceFailure?
    let updateError: InjectedServiceFailure?
    let deleteError: InjectedServiceFailure?

    init(createError: InjectedServiceFailure? = nil, updateError: InjectedServiceFailure? = nil, deleteError: InjectedServiceFailure? = nil) {
        self.createError = createError
        self.updateError = updateError
        self.deleteError = deleteError
    }

    func requestEventAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchWritableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }
    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        if let createError { throw createError }
        return "calendar-id"
    }
    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        if let updateError { throw updateError }
        return externalIdentifier
    }
    func deleteEvent(externalIdentifier: String) throws {
        if let deleteError { throw deleteError }
    }
}

private final class TestReminderService: ReminderServiceProtocol, @unchecked Sendable {
    let createError: InjectedServiceFailure?
    let deadlineError: InjectedServiceFailure?
    let deleteError: InjectedServiceFailure?
    private(set) var deadlineCreateCount = 0

    init(createError: InjectedServiceFailure? = nil, deadlineError: InjectedServiceFailure? = nil, deleteError: InjectedServiceFailure? = nil) {
        self.createError = createError
        self.deadlineError = deadlineError
        self.deleteError = deleteError
    }

    func requestReminderAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchReminderLists() -> [EKCalendar] { [] }
    func defaultReminderList() -> EKCalendar? { nil }
    func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        if let createError { throw createError }
        return "reminder-id"
    }
    func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        if let createError { throw createError }
        return externalIdentifier
    }
    func deleteReminder(externalIdentifier: String) throws {
        if let deleteError { throw deleteError }
    }
    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String {
        deadlineCreateCount += 1
        if let deadlineError { throw deadlineError }
        return "deadline-id"
    }
}

private final class TestNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    let scheduleError: InjectedServiceFailure?

    init(scheduleError: InjectedServiceFailure? = nil) {
        self.scheduleError = scheduleError
    }

    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        if let scheduleError { throw scheduleError }
        return ["notification-id"]
    }
    func removePendingNotifications(identifiers: [String]) {}
    func setupNotificationCategories() {}
}

@MainActor
private final class OfflineSubscriptionService: SubscriptionServiceProtocol {
    private(set) var fetchCount = 0
    var failsOffline = false
    var entitlementSnapshot: EntitlementSnapshot
    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }

    init(snapshot: EntitlementSnapshot = .verified(.starter, provenance: .none)) {
        entitlementSnapshot = snapshot
    }

    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}

    func fetchProducts() async throws -> [Product] {
        fetchCount += 1
        if failsOffline { throw InjectedServiceFailure.offline }
        return []
    }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

// MARK: - Handoff item 1: rescue-commit regressions with no current-tree equivalent
// (port cross-check rescue 816101d -> codex sweep; see docs/HANDOFF.md open loop 1)

@Suite("Rescue regression restoration")
@MainActor
struct RescueRegressionRestorationTests {
    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services() -> ServiceContainer {
        ServiceContainer(
            photoLibrary: TestPhotoLibrary(),
            ocr: OCRService(),
            eventExtraction: EventExtractionService(),
            calendar: TestCalendarService(),
            reminders: TestReminderService(),
            notifications: TestNotificationService(),
            subscription: OfflineSubscriptionService(),
            understanding: EventUnderstandingPipeline.rulesOnly()
        )
    }

    private func candidate() -> EventCandidate {
        EventCandidate(title: "Local Event", startDate: Date().addingTimeInterval(86_400 * 21))
    }

    @Test("Event review draft/discard/commit storage failures are surfaced")
    func eventReviewStorageFailuresAreTyped() async throws {
        let container = try modelContainer()

        let draft = EventReviewViewModel(candidate: candidate(), services: services())
        let draftFailure = draft.saveDraft(modelContext: container.mainContext) {
            throw InjectedServiceFailure.persistence
        }
        guard case .failure = draftFailure else {
            Issue.record("Draft persistence failure must not report completion")
            return
        }
        #expect(draft.errorMessage?.contains("Injected SwiftData failure") == true)

        let discard = EventReviewViewModel(candidate: candidate(), services: services())
        let discardFailure = discard.discard(modelContext: container.mainContext) {
            throw InjectedServiceFailure.persistence
        }
        guard case .failure = discardFailure else {
            Issue.record("Discard persistence failure must not report completion")
            return
        }
        #expect(discard.errorMessage?.contains("Injected SwiftData failure") == true)

        let commit = EventReviewViewModel(candidate: candidate(), services: services())
        let commitFailure = await commit.commitEvent(modelContext: container.mainContext) {
            throw InjectedServiceFailure.persistence
        }
        guard case .failure = commitFailure else {
            Issue.record("Commit persistence failure must not report completion")
            return
        }
        #expect(commit.errorMessage?.contains("could not save the event") == true)
        #expect(!commit.isSavedSuccessfully)
    }

    @Test("SwiftData delete failures return failure and retain the saved record")
    func deleteFailingSaveReturnsFailureAndRetainsData() throws {
        let container = try modelContainer()
        let context = container.mainContext
        let event = candidate()
        let saved = SavedEvent(candidate: event)
        context.insert(event)
        context.insert(saved)
        try context.save()

        let actions = SavedEventActions(
            services: services(),
            modelContext: context,
            saveOperation: { throw InjectedServiceFailure.persistence }
        )

        let result = actions.delete(saved, removeFromCalendar: false)
        guard case .failure(let failure) = result else {
            Issue.record("Delete with a failing save must fail, not report success.")
            return
        }
        #expect(failure.message.contains("Could not save the event changes:"))

        let stillThere = try context.fetch(FetchDescriptor<SavedEvent>()).contains { $0.id == saved.id }
        #expect(stillThere)
    }

    @Test("Notification denial surfaces a human-readable message with the fix path")
    func notificationDenialIsHumanReadable() async throws {
        let container = try modelContainer()
        let review = EventReviewViewModel(
            candidate: candidate(),
            services: ServiceContainer(
                photoLibrary: TestPhotoLibrary(),
                ocr: OCRService(),
                eventExtraction: EventExtractionService(),
                calendar: TestCalendarService(),
                reminders: TestReminderService(),
                notifications: DeniedNotificationService(),
                subscription: OfflineSubscriptionService(),
                understanding: EventUnderstandingPipeline.rulesOnly()
            )
        )

        let result = await review.commitEvent(modelContext: container.mainContext)

        guard case .partial(let issues) = result else {
            Issue.record("Notification denial should produce a partial result, not a failure.")
            return
        }
        #expect(issues.contains { $0.contains("Local notifications: Notifications are denied.") })
        #expect(review.notificationsSkipped)
        #expect(review.errorMessage?.contains("Notifications are denied.") == true)
        #expect(try container.mainContext.fetch(FetchDescriptor<SavedEvent>()).count == 1)
    }
}

private struct DeniedNotificationService: NotificationServiceProtocol {
    func requestAuthorization() async throws -> Bool { false }
    func authorizationStatus() async -> UNAuthorizationStatus { .denied }
    func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        throw DateSnapError.notifications(.accessDenied)
    }
    func removePendingNotifications(identifiers: [String]) {}
    func setupNotificationCategories() {}
}

// MARK: - Gen A denial tests (restored from rescue commit 816101d, adapted to current API)

@Suite("Gen A denial restoration")
@MainActor
struct GenADenialRestorationTests {
    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services(
        photo: TestPhotoLibrary = TestPhotoLibrary(),
        calendar: TestCalendarService = TestCalendarService(),
        reminders: TestReminderService = TestReminderService(),
        notifications: TestNotificationService = TestNotificationService()
    ) -> ServiceContainer {
        ServiceContainer(
            photoLibrary: photo,
            ocr: OCRService(),
            eventExtraction: EventExtractionService(),
            calendar: calendar,
            reminders: reminders,
            notifications: notifications,
            subscription: OfflineSubscriptionService(),
            understanding: EventUnderstandingPipeline.rulesOnly()
        )
    }

    @Test("Denied Photos access is reported and does not trigger a permission prompt")
    func photosDenialDoesNotBlockManualScanPath() async {
        let photos = TestPhotoLibrary(status: .denied)
        let viewModel = HomeViewModel(services: services(photo: photos))

        let allowed = await viewModel.ensurePhotoAccess()

        #expect(!allowed)
        #expect(viewModel.photoAuthorizationStatus == .denied)
        #expect(photos.requestCount == 0)
        #expect(photos.fetchCount == 0)
    }

    @Test("Denied local notifications do not hide a successful Calendar save")
    func notificationDenialIsPartialAndSurfaced() async throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Notification denial", startDate: Date().addingTimeInterval(86_400))
        let review = EventReviewViewModel(
            candidate: candidate,
            services: services(notifications: TestNotificationService(scheduleError: .notification))
        )

        let result = await review.commitEvent(modelContext: container.mainContext)

        guard case .partial(let issues) = result else {
            Issue.record("Notification denial should produce a partial result.")
            return
        }
        #expect(issues.contains { $0.contains("Local notifications") })
        #expect(review.notificationsSkipped)
        #expect(review.errorMessage?.contains("Injected notification failure") == true)
    }
}
