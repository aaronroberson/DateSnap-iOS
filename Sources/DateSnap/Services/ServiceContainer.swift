import Foundation
import SwiftUI

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

}

// MARK: - SwiftUI Environment Integration
@MainActor
private struct ServiceContainerKey: EnvironmentKey {
    static let defaultValue: ServiceContainer? = nil
}

extension EnvironmentValues {
    @MainActor
    public var services: ServiceContainer {
        get {
            guard let services = self[ServiceContainerKey.self] else {
                preconditionFailure("ServiceContainer must be injected at the application or preview root.")
            }
            return services
        }
        set { self[ServiceContainerKey.self] = newValue }
    }
}
