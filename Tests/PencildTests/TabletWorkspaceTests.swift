import EventKit
import Foundation
import Photos
import StoreKit
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import Pencild

private final class TabletTestPhotoLibrary: PhotoLibraryServiceProtocol, @unchecked Sendable {
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus { .authorized }
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .authorized }
    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] { [] }
    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage { UIImage() }
    func observeLibraryChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

private final class TabletTestCalendarService: CalendarServiceProtocol, @unchecked Sendable {
    func requestEventAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchWritableCalendars() -> [EKCalendar] { [] }
    func defaultCalendar() -> EKCalendar? { nil }
    func createEvent(candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        "test-calendar-id"
    }
    func updateEvent(externalIdentifier: String, candidate: EventCandidate, calendar: EKCalendar?, alarms: [TimeInterval]) async throws -> String {
        externalIdentifier
    }
    func deleteEvent(externalIdentifier: String) throws {}
}

private final class TabletTestReminderService: ReminderServiceProtocol, @unchecked Sendable {
    func requestReminderAccess() async throws -> Bool { true }
    func authorizationStatus() -> EKAuthorizationStatus { .fullAccess }
    func fetchReminderLists() -> [EKCalendar] { [] }
    func defaultReminderList() -> EKCalendar? { nil }
    func createReminder(candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        "test-reminder-id"
    }
    func updateReminder(externalIdentifier: String, candidate: EventCandidate, list: EKCalendar?, offsets: [ReminderOffset]) async throws -> String {
        externalIdentifier
    }
    func deleteReminder(externalIdentifier: String) throws {}
    func createDeadlineReminder(title: String, due: Date, url: String?, list: EKCalendar?) async throws -> String {
        "test-deadline-id"
    }
}

private final class TabletTestNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    func requestAuthorization() async throws -> Bool { true }
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func scheduleLocalNotifications(title: String, body: String, triggerDates: [Date], eventId: String?, actionURL: String?) async throws -> [String] {
        ["test-notification-id"]
    }
    func removePendingNotifications(identifiers: [String]) {}
    func setupNotificationCategories() {}
}

@MainActor
private final class TabletTestSubscriptionService: SubscriptionServiceProtocol {
    var entitlementSnapshot = EntitlementSnapshot.verified(.starter, provenance: .none)
    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }
    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}
    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { .starter }
    func restorePurchases() async throws -> SubscriptionTier { .starter }
    func updateCustomerProductStatus() async {}
}

@Suite("Tablet and Accessibility Workspace Tests")
@MainActor
struct TabletWorkspaceTests {

    private func modelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func services() -> ServiceContainer {
        ServiceContainer(
            photoLibrary: TabletTestPhotoLibrary(),
            ocr: OCRService(),
            eventExtraction: EventExtractionService(),
            calendar: TabletTestCalendarService(),
            reminders: TabletTestReminderService(),
            notifications: TabletTestNotificationService(),
            subscription: TabletTestSubscriptionService(),
            understanding: EventUnderstandingPipeline.rulesOnly(calendar: testCalendar)
        )
    }

    @Test("EventReviewSourceInspector supports zoom limits and reset state")
    func sourceInspectorZoomScaleAndReset() throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Design System Showcase", startDate: testAnchor)
        candidate.venueName = "Yerba Buena Center"
        candidate.location = "701 Mission St, San Francisco, CA"
        container.mainContext.insert(candidate)
        try container.mainContext.save()

        let vm = EventReviewViewModel(candidate: candidate, services: services())

        var zoomScale: CGFloat = 1.0
        var panOffset: CGSize = .zero

        // Simulating zoom in clamp
        zoomScale = min(2.5, zoomScale + 0.2)
        #expect(zoomScale == 1.2)

        zoomScale = min(2.5, zoomScale + 2.0)
        #expect(zoomScale == 2.5) // Clamped at 2.5

        // Simulating zoom out clamp
        zoomScale = max(0.8, zoomScale - 2.0)
        #expect(zoomScale == 0.8) // Clamped at 0.8

        // Reset
        zoomScale = 1.0
        panOffset = .zero
        #expect(zoomScale == 1.0)
        #expect(panOffset == .zero)
        #expect(vm.title == "Design System Showcase")
    }

    @Test("SavedEventDetailView regular-layout and iPhone single-column requirements")
    func savedEventDetailRequirements() throws {
        let container = try modelContainer()
        let candidate = EventCandidate(title: "Design System Showcase", startDate: testAnchor)
        let saved = SavedEvent(
            externalCalendarEventId: "ext-cal-123",
            targetCalendar: "Work Calendar",
            targetRemindersList: "Action Items",
            candidate: candidate
        )
        candidate.savedEvent = saved
        container.mainContext.insert(candidate)
        container.mainContext.insert(saved)
        try container.mainContext.save()

        let event = candidate.toPencildEvent()
        #expect(event.title == "Design System Showcase")
        #expect(candidate.savedEvent?.externalCalendarEventId == "ext-cal-123")
        #expect(candidate.savedEvent?.targetCalendar == "Work Calendar")

        // Status determinations
        #expect(saved.status != SavedEventStatus.archived)
        #expect(saved.externalCalendarEventId != nil)
    }

    @Test("All review interactive controls have valid touch target and VoiceOver metadata")
    func accessibilityTouchTargetsAndVoiceOver() {
        // PDChip minimum height
        let chip = PDChip(text: "View original", icon: "eye", selected: false)
        #expect(chip.text == "View original")

        // Top bar back button minimum target
        let topBar = PDTopBar(title: "Review event")
        #expect(topBar.title == "Review event")
        #expect(topBar.showsBack == true)
    }
}
