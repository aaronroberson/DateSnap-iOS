import EventKit
import Foundation
import Photos
import SwiftData
import StoreKit
import Testing
import UIKit
import UserNotifications
@testable import DateSnap

private enum InjectedFailure: Error, LocalizedError, Sendable {
    case calendar
    case reminder
    case notification
    case ocr
    case persistence

    var errorDescription: String? {
        switch self {
        case .calendar: "Injected Calendar failure"
        case .reminder: "Injected Reminders failure"
        case .notification: "Notifications are denied"
        case .ocr: "Injected OCR failure"
        case .persistence: "Injected SwiftData failure"
        }
    }
}

@Suite("Mock data cleanup and failure handling")
@MainActor
struct MockDataCleanupTests {
    @Test("Bundled SampleFlyer uses OCR and rules through review without Photos access")
    func sampleFlyerUsesProductionScanPathWithoutPhotos() async throws {
        let photos = TestPhotoLibrary()
        let services = makeServices(
            photoLibrary: photos,
            ocr: OCRService(),
            understanding: EventUnderstandingPipeline.rulesOnly()
        )
        let viewModel = ScanViewModel(services: services)

        await viewModel.scanSampleFlyer()

        guard case .complete(let candidates) = viewModel.stage else {
            Issue.record("SampleFlyer did not produce a review candidate. Stage: \(viewModel.stage)")
            return
        }
        #expect(!viewModel.rawOcrText.isEmpty)
        #expect(viewModel.lastResult?.route == .rulesOnly)
        #expect(candidates.contains { $0.startDate > .now })
        #expect(photos.requestCalls == 0)
        #expect(photos.fetchCalls == 0)
    }

    @Test("Reminder preview timing comes from the default offsets used by event review")
    func reminderPreviewUsesDefaultOffsets() {
        let eventStart = Date(timeIntervalSince1970: 1_800_000_000)
        let previewDates = ReminderOffset.defaultStaggered.map {
            $0.triggerDate(forEventStart: eventStart, isAllDay: false)
        }

        #expect(previewDates == [
            eventStart.addingTimeInterval(-86_400),
            eventStart.addingTimeInterval(-7_200)
        ])
    }

    @Test("OCR failures reach the scan failure state")
    func ocrFailureIsSurfaced() async {
        let viewModel = ScanViewModel(services: makeServices(ocr: TestOCR(failure: .ocr)))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }

        await viewModel.scanImage(image)

        guard case .failed(let message) = viewModel.stage else {
            Issue.record("OCR failure was not represented as a failed scan.")
            return
        }
        #expect(message.contains("Injected OCR failure"))
    }

    @Test("Denied Photos access is reported and does not trigger a permission prompt")
    func photosDenialDoesNotBlockManualScanPath() async {
        let photos = TestPhotoLibrary(status: .denied)
        let viewModel = HomeViewModel(services: makeServices(photoLibrary: photos))

        let allowed = await viewModel.ensurePhotoAccess()

        #expect(!allowed)
        #expect(viewModel.photoAuthorizationStatus == .denied)
        #expect(photos.requestCalls == 0)
        #expect(photos.fetchCalls == 0)
    }

    @Test("Calendar creation failure is returned to event review")
    func calendarCreateFailureIsTypedAndSurfaced() async throws {
        let calendar = TestCalendarService(createFailure: .calendar)
        let viewModel = EventReviewViewModel(candidate: candidate(), services: makeServices(calendar: calendar))
        let context = try modelContainer().mainContext

        let result = await viewModel.commitEvent(modelContext: context)

        #expect(!result.completed)
        #expect(result.issueMessage?.contains("Injected Calendar failure") == true)
        #expect(viewModel.errorMessage?.contains("Injected Calendar failure") == true)
        #expect(!viewModel.isSavedSuccessfully)
        #expect(calendar.createCalls == 1)
    }

    @Test("Reminder and deadline failures produce a partial save with visible detail")
    func reminderFailuresProducePartialResult() async throws {
        let reminders = TestReminderService(createFailure: .reminder, deadlineFailure: .reminder)
        let event = candidate(rsvpDeadline: Calendar.current.date(byAdding: .day, value: 2, to: .now))
        let viewModel = EventReviewViewModel(candidate: event, services: makeServices(reminders: reminders))
        viewModel.deadlineReminderEnabled = true

        let result = await viewModel.commitEvent(modelContext: try modelContainer().mainContext)

        guard case .partial(let issues) = result else {
            Issue.record("Reminder failures should leave a saved event with a partial result.")
            return
        }
        #expect(issues.contains { $0.contains("Reminders:") })
        #expect(issues.contains { $0.contains("RSVP deadline reminder:") })
        #expect(viewModel.isSavedSuccessfully)
        #expect(viewModel.errorMessage?.contains("incomplete reminders") == true)
    }

    @Test("Denied local notifications do not hide a successful Calendar save")
    func notificationDenialIsPartialAndSurfaced() async throws {
        let notifications = TestNotificationService(scheduleFailure: .notification)
        let viewModel = EventReviewViewModel(candidate: candidate(), services: makeServices(notifications: notifications))

        let result = await viewModel.commitEvent(modelContext: try modelContainer().mainContext)

        guard case .partial(let issues) = result else {
            Issue.record("Notification denial should produce a partial result.")
            return
        }
        #expect(issues.contains { $0.contains("Local notifications:") })
        #expect(viewModel.notificationsSkipped)
        #expect(viewModel.errorMessage?.contains("Notifications are denied") == true)
    }

    @Test("SwiftData save and delete failures return failure without success state")
    func swiftDataFailuresAreTyped() throws {
        let context = try modelContainer().mainContext
        let candidate = candidate()
        context.insert(candidate)
        let actions = SavedEventActions(
            services: makeServices(),
            modelContext: context,
            saveContext: { throw InjectedFailure.persistence }
        )

        let statusResult = actions.setStatus(.archived, for: SavedEvent(candidate: candidate))
        #expect(!statusResult.completed)
        #expect(statusResult.issueMessage?.contains("Injected SwiftData failure") == true)

        let deleteResult = actions.delete(SavedEvent(candidate: candidate), removeFromCalendar: false)
        #expect(!deleteResult.completed)
        #expect(deleteResult.issueMessage?.contains("Injected SwiftData failure") == true)
    }

    @Test("Event review draft, discard and commit storage failures are surfaced")
    func eventReviewStorageFailuresAreTyped() async throws {
        let draft = EventReviewViewModel(candidate: candidate(), services: makeServices())
        let draftFailure = draft.saveDraft(modelContext: try modelContainer().mainContext) {
            throw InjectedFailure.persistence
        }
        #expect(!draftFailure.completed)
        #expect(draft.errorMessage?.contains("Injected SwiftData failure") == true)

        let discard = EventReviewViewModel(candidate: candidate(), services: makeServices())
        let discardFailure = discard.discard(modelContext: try modelContainer().mainContext) {
            throw InjectedFailure.persistence
        }
        #expect(!discardFailure.completed)
        #expect(discard.errorMessage?.contains("Injected SwiftData failure") == true)

        let commit = EventReviewViewModel(candidate: candidate(), services: makeServices())
        let commitFailure = await commit.commitEvent(modelContext: try modelContainer().mainContext) {
            throw InjectedFailure.persistence
        }
        #expect(!commitFailure.completed)
        #expect(commit.errorMessage?.contains("could not save the event") == true)
        #expect(!commit.isSavedSuccessfully)
    }

    @Test("Privacy cache and full erase report SwiftData failures")
    func privacyMutationsReturnFailure() throws {
        let context = try modelContainer().mainContext
        context.insert(ScannedAsset(assetIdentifier: "test", rawOcrText: "event text"))
        let actions = SavedEventActions(
            services: makeServices(),
            modelContext: context,
            saveContext: { throw InjectedFailure.persistence }
        )

        let cacheResult = actions.clearScanCache()
        #expect(!cacheResult.completed)
        #expect(cacheResult.issueMessage?.contains("Injected SwiftData failure") == true)
        #expect(!actions.eraseAllLocalData().completed)
    }

    @Test("Calendar and Reminders deletion failures are partial, retained and reported")
    func externalCleanupFailuresArePartial() throws {
        let context = try modelContainer().mainContext
        let event = candidate()
        let saved = SavedEvent(
            externalCalendarEventId: "calendar-id",
            externalReminderIds: ["reminder-id"],
            candidate: event
        )
        event.savedEvent = saved
        context.insert(event)
        context.insert(saved)
        try context.save()
        let services = makeServices(
            calendar: TestCalendarService(deleteFailure: .calendar),
            reminders: TestReminderService(deleteFailure: .reminder)
        )
        let actions = SavedEventActions(services: services, modelContext: context)

        let result = actions.delete(saved, removeFromCalendar: true)

        guard case .partial(let issues) = result else {
            Issue.record("External cleanup failures should leave a partial result.")
            return
        }
        #expect(issues.contains { $0.contains("Calendar event:") })
        #expect(issues.contains { $0.contains("Reminder reminder-id:") })
        #expect(try context.fetch(FetchDescriptor<SavedEvent>()).contains { $0.id == saved.id })
    }

    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func candidate(rsvpDeadline: Date? = nil) -> EventCandidate {
        EventCandidate(
            title: "Local Event",
            startDate: Calendar.current.date(byAdding: .day, value: 21, to: .now)!,
            rawTextSnippet: "Local Event",
            rsvpDeadline: rsvpDeadline
        )
    }

    private func makeServices(
        photoLibrary: PhotoLibraryServiceProtocol = TestPhotoLibrary(),
        ocr: OCRServiceProtocol = TestOCR(),
        calendar: CalendarServiceProtocol = TestCalendarService(),
        reminders: ReminderServiceProtocol = TestReminderService(),
        notifications: NotificationServiceProtocol = TestNotificationService(),
        subscription: SubscriptionServiceProtocol = TestSubscriptionService(),
        understanding: EventUnderstandingProviding = EventUnderstandingPipeline.rulesOnly()
    ) -> ServiceContainer {
        ServiceContainer(
            photoLibrary: photoLibrary,
            ocr: ocr,
            eventExtraction: EventExtractionService(),
            calendar: calendar,
            reminders: reminders,
            notifications: notifications,
            subscription: subscription,
            understanding: understanding
        )
    }
}

private final class TestPhotoLibrary: PhotoLibraryServiceProtocol, @unchecked Sendable {
    let status: PHAuthorizationStatus
    var requestCalls = 0
    var fetchCalls = 0

    init(status: PHAuthorizationStatus = .denied) {
        self.status = status
    }

    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus {
        requestCalls += 1
        return status
    }

    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { status }

    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] {
        fetchCalls += 1
        return []
    }

    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage {
        throw InjectedFailure.ocr
    }

    func observeLibraryChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

private struct TestOCR: OCRServiceProtocol {
    let failure: InjectedFailure?

    init(failure: InjectedFailure? = nil) {
        self.failure = failure
    }

    func recognizeText(in image: UIImage) async throws -> (fullText: String, confidence: Float) {
        let result = try await recognizeLines(in: image, confidenceFloor: 0)
        return (result.fullText, result.meanConfidence)
    }

    func recognizeLines(in image: UIImage, confidenceFloor: Float) async throws -> OCRResult {
        if let failure { throw failure }
        throw InjectedFailure.ocr
    }
}

private final class TestCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    let createFailure: InjectedFailure?
    let deleteFailure: InjectedFailure?
    var createCalls = 0

    init(createFailure: InjectedFailure? = nil, deleteFailure: InjectedFailure? = nil) {
        self.createFailure = createFailure
        self.deleteFailure = deleteFailure
    }

    func requestEventAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchWritableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }

    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        createCalls += 1
        if let createFailure { throw createFailure }
        return "calendar-id"
    }

    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        if let createFailure { throw createFailure }
        return externalIdentifier
    }

    func deleteEvent(externalIdentifier: String) throws {
        if let deleteFailure { throw deleteFailure }
    }
}

private final class TestReminderService: ReminderServiceProtocol, @unchecked Sendable {
    let createFailure: InjectedFailure?
    let deadlineFailure: InjectedFailure?
    let deleteFailure: InjectedFailure?

    init(
        createFailure: InjectedFailure? = nil,
        deadlineFailure: InjectedFailure? = nil,
        deleteFailure: InjectedFailure? = nil
    ) {
        self.createFailure = createFailure
        self.deadlineFailure = deadlineFailure
        self.deleteFailure = deleteFailure
    }

    func requestReminderAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchReminderLists() -> [EKCalendar] { [] }
    func defaultReminderList() -> EKCalendar? { nil }

    func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        if let createFailure { throw createFailure }
        return "reminder-id"
    }

    func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        if let createFailure { throw createFailure }
        return externalIdentifier
    }

    func deleteReminder(externalIdentifier: String) throws {
        if let deleteFailure { throw deleteFailure }
    }

    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String {
        if let deadlineFailure { throw deadlineFailure }
        return "deadline-id"
    }
}

private struct TestNotificationService: NotificationServiceProtocol {
    let scheduleFailure: InjectedFailure?

    init(scheduleFailure: InjectedFailure? = nil) {
        self.scheduleFailure = scheduleFailure
    }

    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func scheduleLocalNotifications(
        title: String,
        body: String,
        triggerDates: [Date],
        eventId: String?,
        actionURL: String?
    ) async throws -> [String] {
        if let scheduleFailure { throw scheduleFailure }
        return triggerDates.indices.map { "notification-\($0)" }
    }

    func removePendingNotifications(identifiers: [String]) {}
    func setupNotificationCategories() {}
}

@MainActor
private final class TestSubscriptionService: SubscriptionServiceProtocol {
    var currentTier: SubscriptionTier = .starter
    var isSubscribed: Bool { currentTier != .starter }
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { currentTier }
    func restorePurchases() async throws -> SubscriptionTier { currentTier }
    func updateCustomerProductStatus() async {}
}
