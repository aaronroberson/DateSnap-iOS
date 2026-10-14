import Foundation
import StoreKit
import SwiftData
import Testing
import UIKit
@testable import Pencild

@MainActor
private final class ScheduleStubEntitlements: SubscriptionServiceProtocol, @unchecked Sendable {
    var entitlementSnapshot: EntitlementSnapshot
    var currentTier: SubscriptionTier { entitlementSnapshot.tier }
    var isSubscribed: Bool { currentTier != .starter }

    init(_ snapshot: EntitlementSnapshot) { entitlementSnapshot = snapshot }

    func fetchProducts() async throws -> [Product] { [] }
    func purchase(product: Product) async throws -> SubscriptionTier { currentTier }
    func restorePurchases() async throws -> SubscriptionTier { currentTier }
    func updateCustomerProductStatus() async {}
    func refreshEntitlements(_ provenance: EntitlementProvenance) async {}
}

/// Work schedules and multi-date flyers are Premium: other plans see the paywall and nothing is saved.
@Suite("Schedule import gating", .serialized)
@MainActor
struct ScheduleGatingTests {
    private func services(_ snapshot: EntitlementSnapshot, usage: ScanUsageStore) -> ServiceContainer {
        let live = ServiceContainer.live()
        return ServiceContainer(
            photoLibrary: live.photoLibrary, ocr: live.ocr, eventExtraction: live.eventExtraction,
            calendar: live.calendar, reminders: live.reminders, notifications: live.notifications,
            subscription: ScheduleStubEntitlements(snapshot),
            understanding: EventUnderstandingPipeline.rulesOnly(calendar: .current),
            scanUsage: usage
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, ScannedAsset.self, EventCandidate.self, SavedEvent.self, InterpretationRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// A scheduling-app screenshot with three shifts starting next week.
    private func scheduleImage() -> UIImage {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, MMM d"
        let calendar = Calendar.current
        let days = [7, 8, 9].map { formatter.string(from: calendar.date(byAdding: .day, value: $0, to: Date())!) }
        let lines: [(String, CGFloat)] = [
            ("My Schedule", 72),
            (days[0], 48), ("9:00 AM - 5:00 PM", 44), ("Cashier", 40),
            (days[1], 48), ("12:00 PM - 8:00 PM", 44), ("Stock", 40),
            (days[2], 48), ("10:00 AM - 6:00 PM", 44), ("Cashier", 40),
        ]
        let size = CGSize(width: 1080, height: 1500)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var y: CGFloat = 80
            for (text, pointSize) in lines {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: pointSize, weight: .semibold),
                    .foregroundColor: UIColor.black
                ]
                (text as NSString).draw(at: CGPoint(x: 80, y: y), withAttributes: attributes)
                y += pointSize * 1.6
            }
        }
    }

    @Test("Starter and Plus are sent to the Premium paywall, with nothing saved and no scan used",
          arguments: [SubscriptionTier.starter, .plus])
    func lowerPlansAreGated(tier: SubscriptionTier) async throws {
        let usage = ScanUsageStore.forTesting()
        let container = try makeContainer()
        let scan = ScanViewModel(services: services(.verified(tier, provenance: .storeKit), usage: usage))

        await scan.scanImage(scheduleImage(), modelContext: container.mainContext)

        #expect(scan.stage == .requiresUpgrade(.scheduleImport))
        #expect(try container.mainContext.fetch(FetchDescriptor<EventCandidate>()).isEmpty)
        #expect(usage.scansUsed() == 0)
    }

    @Test("Premium imports every shift as its own event")
    func premiumImportsEachShift() async throws {
        let container = try makeContainer()
        let scan = ScanViewModel(services: services(.verified(.premium, provenance: .storeKit), usage: .forTesting()))

        await scan.scanImage(scheduleImage(), modelContext: container.mainContext)

        guard case .complete(let candidates) = scan.stage else {
            Issue.record("Expected a completed scan, got \(scan.stage)")
            return
        }
        #expect(candidates.count == 3)
    }

    @Test("A single flyer is not gated on the free plan")
    func singleFlyerIsNotGated() async throws {
        let container = try makeContainer()
        let scan = ScanViewModel(services: services(.verified(.starter, provenance: .storeKit), usage: .forTesting()))

        await scan.scanSampleFlyer(modelContext: container.mainContext)

        #expect(scan.stage != .requiresUpgrade(.scheduleImport))
    }

    @Test("A batch that meets a schedule on a lower plan flags it for the Premium upgrade path")
    func batchFlagsLockedFeature() async throws {
        let services = services(.verified(.plus, provenance: .storeKit), usage: .forTesting())
        let scanner = BatchScanViewModel(services: services)
        let container = try makeContainer()

        await scanner.scan([.loaded(id: "a", image: scheduleImage())], modelContext: container.mainContext)

        #expect(scanner.lockedFeature == .scheduleImport)
        let session = BatchReviewSession(scan: scanner, services: services)
        #expect(session.lockedFeature == .scheduleImport)
        #expect(session.events.isEmpty)
    }
}
