import Foundation
import StoreKit
import SwiftData
import Testing
@testable import Pencild

@MainActor
private final class StubEntitlements: SubscriptionServiceProtocol, @unchecked Sendable {
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

extension ScanUsageStore {
    /// A store backed by a throwaway defaults suite, so tests never touch the simulator's real count.
    static func forTesting() -> ScanUsageStore {
        ScanUsageStore(defaults: UserDefaults(suiteName: "pencild.tests.\(UUID().uuidString)")!)
    }
}

@Suite("Free plan limits", .serialized)
@MainActor
struct PlanLimitsTests {
    private func freshUsage() -> ScanUsageStore { .forTesting() }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test("Free plan allows 10 scans a month and resets on the 1st")
    func monthlyAllowance() {
        let usage = freshUsage()
        for _ in 0..<10 { usage.recordScan(at: date(2026, 10, 5), calendar: testCalendar) }
        #expect(usage.remainingFreeScans(at: date(2026, 10, 31), calendar: testCalendar) == 0)
        #expect(usage.remainingFreeScans(at: date(2026, 11, 1), calendar: testCalendar) == 10)
    }

    @Test("Only a verified paid plan lifts the limits; an unresolved check is the free plan")
    func whoIsLimited() {
        let unverifiedPremium = EntitlementSnapshot(tier: .premium, state: .unverified, provenance: .storeKit)
        let unavailable = EntitlementSnapshot(tier: .plus, state: .unavailable, provenance: .storeKit)
        #expect(PlanLimits.limitsScans(.verified(.starter, provenance: .storeKit)))
        #expect(!PlanLimits.limitsScans(.verified(.plus, provenance: .storeKit)))
        #expect(PlanLimits.limitsScans(.checking()))
        #expect(PlanLimits.limitsScans(unverifiedPremium))
        #expect(PlanLimits.limitsScans(unavailable))
        #expect(PlanLimits.maxAlertsPerEvent(.verified(.starter, provenance: .storeKit)) == 1)
        #expect(PlanLimits.maxAlertsPerEvent(.verified(.plus, provenance: .storeKit)) == 3)
        #expect(PlanLimits.maxAlertsPerEvent(.verified(.premium, provenance: .storeKit)) == 3)
        #expect(PlanLimits.maxAlertsPerEvent(.checking()) == 1)
        #expect(PlanLimits.maxAlertsPerEvent(unverifiedPremium) == 1)
    }

    private func services(_ snapshot: EntitlementSnapshot, usage: ScanUsageStore) -> ServiceContainer {
        let live = ServiceContainer.live()
        return ServiceContainer(
            photoLibrary: live.photoLibrary, ocr: live.ocr, eventExtraction: live.eventExtraction,
            calendar: live.calendar, reminders: live.reminders, notifications: live.notifications,
            subscription: StubEntitlements(snapshot),
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

    @Test("A scan that finds an event uses one free scan; rescanning the same flyer does not")
    func scansCountOnlyNewEvents() async throws {
        let usage = freshUsage()
        let container = try makeContainer()
        let context = container.mainContext
        let scan = ScanViewModel(services: services(.verified(.starter, provenance: .storeKit), usage: usage))

        await scan.scanSampleFlyer(modelContext: context)
        #expect(usage.scansUsed() == 1)
        scan.reset()
        await scan.scanSampleFlyer(modelContext: context)
        #expect(usage.scansUsed() == 1, "Resuming an unsaved scan must not use another free scan")
    }

    @Test("When the free allowance is used up the scan stops before reading the image")
    func exhaustedAllowanceBlocks() async throws {
        let usage = freshUsage()
        for _ in 0..<PlanLimits.freeScansPerMonth { usage.recordScan() }
        let scan = ScanViewModel(services: services(.verified(.starter, provenance: .storeKit), usage: usage))

        let container = try makeContainer()
        await scan.scanSampleFlyer(modelContext: container.mainContext)
        #expect(scan.stage == .scanLimitReached)
        #expect(scan.extractedCandidates.isEmpty)
    }

    @Test("Plus is never blocked by the free allowance")
    func plusIsUnlimited() async throws {
        let usage = freshUsage()
        for _ in 0..<PlanLimits.freeScansPerMonth { usage.recordScan() }
        let scan = ScanViewModel(services: services(.verified(.plus, provenance: .storeKit), usage: usage))

        let container = try makeContainer()
        await scan.scanSampleFlyer(modelContext: container.mainContext)
        #expect(scan.stage != .scanLimitReached)
    }

    @Test("A batch that runs out of free scans flags it for the upgrade path")
    func batchFlagsScanLimit() async throws {
        let usage = freshUsage()
        for _ in 0..<PlanLimits.freeScansPerMonth { usage.recordScan() }
        let services = services(.verified(.starter, provenance: .storeKit), usage: usage)
        let scanner = BatchScanViewModel(services: services)
        let container = try makeContainer()

        await scanner.scan([.loaded(id: "a", image: SampleFlyer.render())], modelContext: container.mainContext)

        #expect(scanner.hitScanLimit)
        let session = BatchReviewSession(scan: scanner, services: services)
        #expect(session.hitScanLimit)
        #expect(session.events.isEmpty)
    }

    @Test("A free-plan review starts with at most one alert; Plus keeps up to three")
    func reviewAlertsFollowPlan() async throws {
        let container = try makeContainer()
        let scan = ScanViewModel(services: services(.verified(.plus, provenance: .storeKit), usage: freshUsage()))
        await scan.scanSampleFlyer(modelContext: container.mainContext)
        let candidate = try #require(scan.extractedCandidates.first)

        let free = EventReviewViewModel(candidate: candidate, services: services(.verified(.starter, provenance: .storeKit), usage: freshUsage()))
        #expect(free.maxAlerts == 1)
        #expect(free.selectedOffsets.count <= 1)

        let plus = EventReviewViewModel(candidate: candidate, services: services(.verified(.plus, provenance: .storeKit), usage: freshUsage()))
        #expect(plus.maxAlerts == 3)
        #expect(plus.selectedOffsets.count > 1)
    }

    @Test("A batch larger than the free allowance is held back with the exact excess")
    func batchPreflight() {
        let free = EntitlementSnapshot.verified(.starter, provenance: .storeKit)
        #expect(PlanLimits.batchExcess(selecting: 5, snapshot: free, remaining: 3) == 2)
        #expect(PlanLimits.batchExcess(selecting: 3, snapshot: free, remaining: 3) == 0)
        #expect(PlanLimits.batchExcess(selecting: 4, snapshot: free, remaining: 0) == 4)
        #expect(PlanLimits.batchExcess(selecting: 40, snapshot: .verified(.plus, provenance: .storeKit), remaining: 0) == 0)
        #expect(PlanLimits.batchExcess(selecting: 40, snapshot: .checking(), remaining: 0) == 40)
    }

    @Test("The over-limit prompt states the selection, what's left, and how many to deselect")
    func overLimitMessage() {
        let partial = BatchOverLimit(selected: 5, remaining: 3)
        #expect(partial.excess == 2)
        #expect(partial.message.contains("selected 5"))
        #expect(partial.message.contains("3 free scans left"))
        #expect(partial.message.contains("Deselect 2"))
        let none = BatchOverLimit(selected: 4, remaining: 0)
        #expect(none.message.contains("used this month's \(PlanLimits.freeScansPerMonth) free scans"))
    }
}
