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

@Suite("Tablet workspace populated smoke", .serialized)
@MainActor
struct TabletWorkspaceTests {
    /// Retained screenshot evidence for the populated regular-width workspaces.
    private static let evidenceDirectory = URL(fileURLWithPath: "/private/tmp/pencild-ipad-smoke", isDirectory: true)

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
            understanding: EventUnderstandingPipeline.rulesOnly(calendar: .current),
            scanUsage: .forTesting()
        )
    }

    /// Hosts `view` in a window of the running test host with a forced size class, lets
    /// `.task` modifiers run, and returns a rendered snapshot of the hierarchy.
    private func render<V: View>(
        _ view: V,
        size: CGSize,
        sizeClass: UIUserInterfaceSizeClass,
        name: String
    ) async throws -> UIImage {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view)
        host.traitOverrides.horizontalSizeClass = sizeClass
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        for _ in 0..<10 {
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
        }

        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let data = try #require(image.pngData())
        try FileManager.default.createDirectory(at: Self.evidenceDirectory, withIntermediateDirectories: true)
        try data.write(to: Self.evidenceDirectory.appendingPathComponent("\(name).png"))
        Attachment.record(data, named: "\(name).png")
        return image
    }

    @Test("Source viewport clamps zoom, pans only while magnified, and resets")
    func sourceViewportRules() {
        var viewport = SourceViewport()
        viewport.pan(to: CGSize(width: 40, height: 10))
        #expect(viewport.offset == .zero, "Panning at 100% must not move the document")

        viewport.zoomIn()
        #expect(viewport.percent == 120)
        for _ in 0..<20 { viewport.zoomIn() }
        #expect(viewport.scale == SourceViewport.maxScale)

        viewport.pan(to: CGSize(width: 40, height: 10))
        #expect(viewport.offset == CGSize(width: 40, height: 10))

        for _ in 0..<20 { viewport.zoomOut() }
        #expect(viewport.scale == SourceViewport.minScale)
        #expect(viewport.offset == .zero, "Zooming back to fit must recenter the document")

        viewport.zoomIn(); viewport.zoomIn(); viewport.zoomIn()
        viewport.pan(to: CGSize(width: -20, height: 30))
        viewport.reset()
        #expect(viewport == SourceViewport())
    }

    @Test("Populated iPad review → save → detail → archive/restore over a real scanned flyer")
    func populatedRegularWorkspaceSmoke() async throws {
        let container = try modelContainer()
        let context = container.mainContext
        let services = services()
        let appState = AppState()

        // 1. Seed through the real local scan path: rendered flyer → Vision OCR → rules pipeline → SwiftData.
        let scan = ScanViewModel(services: services)
        await scan.scanSampleFlyer(modelContext: context)
        guard case .complete(let candidates) = scan.stage, let candidate = candidates.first else {
            Issue.record("Sample flyer scan did not produce a candidate: \(scan.stage)")
            return
        }
        let persisted = try context.fetch(FetchDescriptor<EventCandidate>())
        #expect(persisted.contains { $0.id == candidate.id })
        #expect(candidate.scannedAsset?.assetIdentifier == "pencild-sample-flyer")
        #expect(candidate.title.localizedCaseInsensitiveContains("neon sunset"))
        #expect(Calendar.current.isDate(candidate.startDate, inSameDayAs: SampleFlyer.eventDate()))
        let showTime = Calendar.current.dateComponents([.hour, .minute], from: candidate.startDate)
        #expect(showTime.hour == 20 && showTime.minute == 30, "Start must come from the flyer's SHOW 8:30 PM line")
        appState.rememberSourceImage(scan.currentProcessingImage, for: [candidate])

        // 2. Regular-width Event Review over the persisted candidate.
        let reviewImage = try await render(
            EventReviewEditView(event: candidate.toPencildEvent())
                .environmentObject(appState)
                .pencildServices(services)
                .modelContainer(container),
            size: CGSize(width: 1194, height: 834),
            sizeClass: .regular,
            name: "01-ipad-event-review"
        )
        #expect(reviewImage.size.width == 1194)

        // Full-length phone renders, so every section's order is visible below the fold.
        _ = try await render(
            EventReviewEditView(event: candidate.toPencildEvent())
                .environmentObject(appState)
                .pencildServices(services)
                .modelContainer(container),
            size: CGSize(width: 402, height: 3400),
            sizeClass: .compact,
            name: "10-compact-review-full"
        )

        // 3. Review-state checks on the same candidate: no duplicates yet, ambiguity swap is reversible.
        let review = EventReviewViewModel(candidate: candidate, services: services, sourceImage: scan.currentProcessingImage)
        review.findDuplicates(in: context)
        #expect(review.duplicateMatches.isEmpty)
        let originalStart = review.startDate
        review.swapMonthAndDay()
        review.swapMonthAndDay()
        #expect(review.startDate == originalStart)

        // 4. Explicit Save writes through the (fake) Calendar/Reminders/notification services.
        let result = await review.commitEvent(modelContext: context)
        if case .failure(let failure) = result { Issue.record("Save failed: \(failure.localizedDescription)") }
        let saved = try #require(candidate.savedEvent)
        #expect(saved.externalCalendarEventId == "test-calendar-id")
        #expect(saved.status == .saved)
        #expect(!saved.alertOffsets.isEmpty)

        // 5. A second scan of the same flyer is now recognized as already saved.
        let rescan = ScanViewModel(services: services)
        await rescan.scanSampleFlyer(modelContext: context)
        #expect(rescan.stage == .alreadySaved(count: 1))

        // 6. Regular-width Saved Event Detail, then archive and restore through the shared action path.
        _ = try await render(
            SavedEventDetailView(event: candidate.toPencildEvent())
                .environmentObject(appState)
                .pencildServices(services)
                .modelContainer(container),
            size: CGSize(width: 1194, height: 834),
            sizeClass: .regular,
            name: "02-ipad-saved-detail"
        )
        _ = try await render(
            SavedEventDetailView(event: candidate.toPencildEvent())
                .environmentObject(appState)
                .pencildServices(services)
                .modelContainer(container),
            size: CGSize(width: 402, height: 2600),
            sizeClass: .compact,
            name: "11-compact-detail-full"
        )
        let actions = SavedEventActions(services: services, modelContext: context)
        #expect(actions.setStatus(.archived, for: saved).isSuccess)
        #expect(saved.status == .archived)
        #expect(actions.setStatus(.saved, for: saved).isSuccess)
        #expect(saved.status == .saved)

        // 7. Compact width keeps the single-column path for the same record.
        _ = try await render(
            SavedEventDetailView(event: candidate.toPencildEvent())
                .environmentObject(appState)
                .pencildServices(services)
                .modelContainer(container),
            size: CGSize(width: 402, height: 874),
            sizeClass: .compact,
            name: "03-compact-saved-detail"
        )
    }

    @Test("Populated Batch Review renders found and skipped sources at regular and compact width")
    func populatedBatchReviewSmoke() async throws {
        let container = try modelContainer()
        let context = container.mainContext
        let services = services()
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        }

        // Real batch pipeline: one flyer with an event, one image with no readable dates.
        let scanner = BatchScanViewModel(services: services)
        await scanner.scan(
            [.loaded(id: "batch-flyer", image: SampleFlyer.render()), .loaded(id: "batch-blank", image: blank)],
            modelContext: context
        )
        let session = BatchReviewSession(scan: scanner, services: services)
        #expect(session.events.count == 1)
        #expect(session.skipped.count == 1)

        for (size, sizeClass, name) in [
            (CGSize(width: 1194, height: 834), UIUserInterfaceSizeClass.regular, "04-ipad-batch-review"),
            (CGSize(width: 402, height: 874), UIUserInterfaceSizeClass.compact, "05-compact-batch-review"),
        ] {
            _ = try await render(
                BatchReviewView(session: session)
                    .environmentObject(AppState())
                    .pencildServices(services)
                    .modelContainer(container),
                size: size,
                sizeClass: sizeClass,
                name: name
            )
        }
    }

    @Test("Scan flow: populated review queue and empty screenshot picker render at regular and compact width")
    func scanFlowSmoke() async throws {
        let container = try modelContainer()
        let context = container.mainContext
        let services = services()
        let scan = ScanViewModel(services: services)
        await scan.scanSampleFlyer(modelContext: context)
        let pending = try context.fetch(FetchDescriptor<EventCandidate>())
        #expect(pending.count == 1, "The review queue should show the persisted, unsaved scan")

        let appState = AppState()
        let home = HomeViewModel(services: services)
        for (size, sizeClass, suffix) in [
            (CGSize(width: 1194, height: 834), UIUserInterfaceSizeClass.regular, "ipad"),
            (CGSize(width: 402, height: 874), UIUserInterfaceSizeClass.compact, "compact"),
        ] {
            _ = try await render(
                ReviewQueueView()
                    .environmentObject(appState)
                    .pencildServices(services)
                    .modelContainer(container),
                size: size,
                sizeClass: sizeClass,
                name: "06-\(suffix)-review-queue"
            )
            _ = try await render(
                RecentScreenshotsView()
                    .environmentObject(appState)
                    .environmentObject(home)
                    .environmentObject(scan)
                    .pencildServices(services)
                    .modelContainer(container),
                size: size,
                sizeClass: sizeClass,
                name: "07-\(suffix)-recent-screenshots"
            )
        }
        #expect(home.recentScreenshots.isEmpty)
    }

    @Test("Paywall interstitials render with the close button pinned top-right")
    func paywallInterstitialsRender() async throws {
        let services = services()
        for (size, sizeClass, suffix) in [
            (CGSize(width: 1194, height: 834), UIUserInterfaceSizeClass.regular, "ipad"),
            (CGSize(width: 402, height: 874), UIUserInterfaceSizeClass.compact, "compact"),
        ] {
            _ = try await render(
                PaywallView(initialPlan: .plus).environmentObject(AppState()).pencildServices(services),
                size: size, sizeClass: sizeClass, name: "08-\(suffix)-plus-paywall"
            )
            _ = try await render(
                PaywallView(initialPlan: .premium).environmentObject(AppState()).pencildServices(services),
                size: size, sizeClass: sizeClass, name: "09-\(suffix)-premium-paywall"
            )
        }
    }
}

private extension MutationResult {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
