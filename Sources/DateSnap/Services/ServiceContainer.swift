import Foundation
import SwiftUI
import Photos
import EventKit
import StoreKit

// MARK: - Central Dependency Injection Hub
public final class ServiceContainer: ObservableObject, @unchecked Sendable {
    public let photoLibrary: PhotoLibraryServiceProtocol
    public let ocr: OCRServiceProtocol
    public let eventExtraction: EventExtractionServiceProtocol
    public let calendar: CalendarServiceProtocol
    public let reminders: ReminderServiceProtocol
    public let notifications: NotificationServiceProtocol
    public let subscription: SubscriptionServiceProtocol
    /// OCR → deterministic extraction → optional on-device interpretation → validated review bundle.
    public let understanding: EventUnderstandingProviding

    public init(
        photoLibrary: PhotoLibraryServiceProtocol,
        ocr: OCRServiceProtocol,
        eventExtraction: EventExtractionServiceProtocol,
        calendar: CalendarServiceProtocol,
        reminders: ReminderServiceProtocol,
        notifications: NotificationServiceProtocol,
        subscription: SubscriptionServiceProtocol,
        understanding: EventUnderstandingProviding = EventUnderstandingPipeline.rulesOnly()
    ) {
        self.photoLibrary = photoLibrary
        self.ocr = ocr
        self.eventExtraction = eventExtraction
        self.calendar = calendar
        self.reminders = reminders
        self.notifications = notifications
        self.subscription = subscription
        self.understanding = understanding
    }

    // MARK: - Live Production Container
    @MainActor
    public static func live() -> ServiceContainer {
        let photoService = PhotoLibraryService()
        let ocrService = OCRService()
        let extractionService = EventExtractionService()
        let calendarService = CalendarService()
        let reminderService = ReminderService()
        let notificationService = NotificationService()
        let subscriptionService = SubscriptionService.shared

        return ServiceContainer(
            photoLibrary: photoService,
            ocr: ocrService,
            eventExtraction: extractionService,
            calendar: calendarService,
            reminders: reminderService,
            notifications: notificationService,
            subscription: subscriptionService,
            understanding: IntelligenceComposition.liveUnderstanding()
        )
    }

    // MARK: - Mock Container for Previews and Unit Testing
    @MainActor
    public static func mock() -> ServiceContainer {
        return ServiceContainer(
            photoLibrary: MockPhotoLibraryService(),
            ocr: MockOCRService(),
            eventExtraction: MockEventExtractionService(),
            calendar: MockCalendarService(),
            reminders: MockReminderService(),
            notifications: MockNotificationService(),
            subscription: MockSubscriptionService()
        )
    }
}

// MARK: - SwiftUI Environment Integration
@MainActor
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer = ServiceContainer.mock()
}

extension EnvironmentValues {
    @MainActor
    public var services: ServiceContainer {
        get { self[ServiceContainerKey.self] }
        set { self[ServiceContainerKey.self] = newValue }
    }
}

// MARK: - Mock Implementations for Tests & Previews

public final class MockPhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
    public init() {}
    public func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus { .authorized }
    public func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .authorized }
    public func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] { [] }
    public func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage { UIImage() }
    public func observeLibraryChanges() -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}

public final class MockOCRService: OCRServiceProtocol {
    public init() {}
    public func recognizeText(in image: UIImage) async throws -> (fullText: String, confidence: Float) {
        return ("SAMPLE EVENT\nJULY 18 2025 7:00 PM\nSKYBAR LA", 0.98)
    }
    public func recognizeLines(in image: UIImage, confidenceFloor: Float) async throws -> OCRResult {
        let lines = [
            OCRLine(text: "SAMPLE EVENT", confidence: 0.99, boundingBox: CGRect(x: 0.1, y: 0.85, width: 0.8, height: 0.08)),
            OCRLine(text: "JULY 18 2025 7:00 PM", confidence: 0.98, boundingBox: CGRect(x: 0.1, y: 0.70, width: 0.6, height: 0.05)),
            OCRLine(text: "SKYBAR LA", confidence: 0.97, boundingBox: CGRect(x: 0.1, y: 0.60, width: 0.5, height: 0.04))
        ]
        return OCRResult(fullText: "SAMPLE EVENT\nJULY 18 2025 7:00 PM\nSKYBAR LA", lines: lines, meanConfidence: 0.98)
    }
}

public final class MockEventExtractionService: EventExtractionServiceProtocol {
    public init() {}
    public func extractCandidates(from text: String, locale: Locale) async -> [EventCandidate] {
        let sample = EventCandidate(
            title: "Mock Rooftop Sunset Party",
            startDate: Date().addingTimeInterval(86400 * 5),
            endDate: Date().addingTimeInterval(86400 * 5 + 7200),
            isAllDay: false,
            location: "8440 Sunset Blvd, Los Angeles, CA",
            venueName: "Skybar Lounge",
            rsvpUrl: "https://datesnap.app/rsvp",
            confidenceScore: 0.96,
            yearAssumed: false,
            rawTextSnippet: text
        )
        return [sample]
    }
    public func extractCandidates(from result: OCRResult, locale: Locale) async -> [EventCandidate] {
        await extractCandidates(from: result.fullText, locale: locale)
    }
}

public final class MockCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    public init() {}
    public func requestEventAccess() async throws -> Bool { true }
    public func authorizationStatus() -> EKAuthorizationStatus {
        if #available(iOS 17.0, *) { return .fullAccess } else { return .authorized }
    }
    public func fetchWritableCalendars() -> [EKCalendar] { [] }
    public func defaultCalendar() -> EKCalendar? { nil }
    public func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        return "mock-calendar-event-\(UUID().uuidString)"
    }
    public func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        externalIdentifier
    }
    public func deleteEvent(externalIdentifier: String) throws {}
}

public final class MockReminderService: ReminderServiceProtocol, @unchecked Sendable {
    public init() {}
    public func requestReminderAccess() async throws -> Bool { true }
    public func authorizationStatus() -> EKAuthorizationStatus {
        if #available(iOS 17.0, *) { return .fullAccess } else { return .authorized }
    }
    public func fetchReminderLists() -> [EKCalendar] { [] }
    public func defaultReminderList() -> EKCalendar? { nil }
    public func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        return "mock-reminder-\(UUID().uuidString)"
    }
    public func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        externalIdentifier
    }
    public func deleteReminder(externalIdentifier: String) throws {}
    public func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String {
        "mock-deadline-\(UUID().uuidString)"
    }
}

public final class MockNotificationService: NotificationServiceProtocol {
    public init() {}
    public func requestAuthorization() async throws -> Bool { true }
    public func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    public func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        return triggerDates.enumerated().map { "mock-notification-\($0.offset)" }
    }
    public func removePendingNotifications(identifiers: [String]) {}
    public func setupNotificationCategories() {}
}

@MainActor
public final class MockSubscriptionService: SubscriptionServiceProtocol, @unchecked Sendable {
    public init() {}
    public var currentTier: SubscriptionTier { .plus }
    public var isSubscribed: Bool { true }
    public func fetchProducts() async throws -> [Product] { [] }
    public func purchase(product: Product) async throws -> SubscriptionTier { .plus }
    public func restorePurchases() async throws -> SubscriptionTier { .plus }
    public func updateCustomerProductStatus() async {}
}
