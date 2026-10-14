import SwiftUI
import Combine
import SwiftData

@MainActor
protocol ToastDismissalScheduling {
    func scheduleDismissal(_ action: @escaping @MainActor @Sendable () -> Void)
}

private struct LiveToastDismissalScheduler: ToastDismissalScheduling {
    func scheduleDismissal(_ action: @escaping @MainActor @Sendable () -> Void) {
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            action()
        }
    }
}

enum ActiveTab: String, CaseIterable, Identifiable, Sendable {
    case home = "Home"
    case agenda = "Agenda"
    case review = "Review"
    case settings = "Settings"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .agenda: return "calendar"
        case .review: return "text.bubble.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

enum AgendaDateFilter: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming"
    case today = "Today"
    case next7Days = "Next 7 Days"
    case past = "Past"
    case all = "All"

    var id: String { rawValue }

    /// The app's single definition of these ranges. "Upcoming" starts at the beginning of today, so
    /// an event earlier today is still upcoming until the day ends (History's smart filter and
    /// "RSVP Due" use this too).
    func includes(_ date: Date, relativeTo today: Date, calendar: Calendar = .current) -> Bool {
        let startOfToday = calendar.startOfDay(for: today)
        switch self {
        case .upcoming: return date >= startOfToday
        case .today: return calendar.isDate(date, inSameDayAs: today)
        case .next7Days:
            let end = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
            return date >= startOfToday && date < end
        case .past: return date < startOfToday
        case .all: return true
        }
    }
}

enum AppModalScreen: Identifiable, Sendable {
    /// The paywall, opening on the given plan's tab.
    case paywall(opening: PurchaseViewModel.Plan)
    case calendarPermissionDenied
    case notificationPermissionDenied
    case noDatesFound
    case savedEventDetail(PencildEvent)
    case eventReviewEdit(PencildEvent)
    case reminderScheduleEditor(PencildEvent)
    case recentScreenshots
    case captureSources
    case screenGallery
    case userProfile
    case defaultCalendar
    
    var isPaywall: Bool {
        if case .paywall = self { return true }
        return false
    }

    /// The paywall opened on the tab of the plan `feature` needs.
    static func paywall(for feature: PremiumFeature) -> AppModalScreen {
        .paywall(opening: feature.requiredTier == .premium ? .premium : .plus)
    }

    var id: String {
        switch self {
        case .paywall(let plan): return plan == .premium ? "paywall-premium" : "paywall-plus"
        case .calendarPermissionDenied: return "calendarPermissionDenied"
        case .notificationPermissionDenied: return "notificationPermissionDenied"
        case .noDatesFound: return "noDatesFound"
        case .savedEventDetail(let event): return "savedEventDetail-\(event.id)"
        case .eventReviewEdit(let event): return "eventReviewEdit-\(event.id)"
        case .reminderScheduleEditor(let event): return "reminderScheduleEditor-\(event.id)"
        case .recentScreenshots: return "recentScreenshots"
        case .captureSources: return "captureSources"
        case .screenGallery: return "screenGallery"
        case .userProfile: return "userProfile"
        case .defaultCalendar: return "defaultCalendar"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: ActiveTab = .home
    /// History & Archive is pushed from Agenda rather than living in the tab bar.
    @Published var showHistory = false
    @Published var activeModal: AppModalScreen? = nil

    // Membership tier, mirrored from StoreKit via SubscriptionService.
    /// Mirror of the subscription service's entitlement snapshot. Every decision below derives from
    /// it through `FeatureAccessPolicy` (see `EntitlementProviding`), so an unresolved StoreKit
    /// check counts as free here exactly as it does in the view models.
    @Published private(set) var entitlementSnapshot: EntitlementSnapshot = .checking()
    /// The effective tier: verified tier, or free while unresolved.
    var subscriptionTier: SubscriptionTier { entitlementSnapshot.effectiveTier }
    var isPlusMember: Bool { subscriptionTier != .starter }
    var isPremiumMember: Bool { subscriptionTier == .premium }
    var entitlementsUnresolved: Bool { entitlementSnapshot.isUnresolved }
    private var entitlementProvider: (any SubscriptionServiceProtocol)?

    /// Premium includes every Plus feature (tiers are ranked). Unresolved entitlements count as free.
    func isEntitled(to feature: PremiumFeature) -> Bool {
        FeatureAccessPolicy.decision(for: feature, snapshot: entitlementSnapshot) == .allowed
    }

    /// Whether a paywall should open now. Re-requests an unresolved entitlement first; if that
    /// shows a paid plan, says so instead of selling it. A Premium member is never shown a paywall.
    /// `present(_:)` and the paywall view (for screens that open it in their own sheet) both ask.
    func shouldShowPaywall() async -> Bool {
        if let provider = entitlementProvider, entitlementSnapshot.isUnresolved {
            let before = subscriptionTier
            entitlementSnapshot = await provider.resolveBeforeUpsell()
            if before == .starter && subscriptionTier != .starter {
                showToast("Your \(subscriptionTier.displayName) plan is active. Try that again.")
                return false
            }
        }
        return subscriptionTier != .premium
    }

    // Scan context handed from the scan pipeline to the review / no-dates screens.
    @Published var lastScanRawText: String = ""
    @Published var lastScanImage: UIImage? = nil
    /// Source images keyed by candidate id, so the review screen can show what was scanned this session.
    private(set) var sourceImages: [String: UIImage] = [:]
    /// Set by "Scan another photo" flows to reopen the photo picker from Home.
    @Published var requestPhotoPicker: Bool = false
    @Published var requestFileImporter: Bool = false
    @Published var requestDocumentScanner: Bool = false
    @Published var requestScreenshotPicker: Bool = false
    /// Multi-screenshot batch session; presented as its own sheet with per-event destinations.
    @Published var batchReviewSession: BatchReviewSession? = nil
    /// In-flight multi-screenshot scan, kept here so progress survives picker dismissal.
    @Published private(set) var activeBatchScan: BatchScanViewModel? = nil
    @Published private(set) var isBatchScanning = false

    // MARK: - Navigation
    // Tabs change through `selectedTab`; History through `openHistory()`. Every modal sheet is
    // shown through `present(_:)` and every batch review through `presentBatchReview(_:)`, so a
    // sheet already on screen is always dismissed before the next one appears.

    /// How long SwiftUI needs to finish dismissing a sheet before another can be presented.
    static let sheetDismissalDelay: Duration = .milliseconds(400)

    /// Presents a modal, first dismissing any sheet already on screen.
    func present(_ modal: AppModalScreen) async {
        if modal.isPaywall, await !shouldShowPaywall() { return }
        await dismissPresentedSheets()
        activeModal = modal
    }

    /// Starts a scan source chosen outside Home (the Add events sheet). Home owns the pickers,
    /// scan limits and batch prompts, so this switches to it and raises the matching request.
    func beginCapture(_ source: CaptureSource) async {
        await dismissPresentedSheets()
        selectedTab = .home
        switch source {
        case .screenshots: requestScreenshotPicker = true
        case .photoLibrary: requestPhotoPicker = true
        case .fileImport: requestFileImporter = true
        case .documentScanner: requestDocumentScanner = true
        case .manual: break // Needs a model context; the caller creates the event and presents the form.
        }
    }

    /// Enter Manually (Home, Add events sheet) and No Dates Found (with a scan prefill): builds the
    /// event through `ManualEventFactory` and opens the review form.
    func startManualEntry(
        in context: ModelContext,
        prefill: ManualEventFactory.ScanPrefill? = nil,
        sourceImage: UIImage? = nil
    ) async {
        do {
            let candidate = try ManualEventFactory.makeCandidate(in: context, prefill: prefill)
            rememberSourceImage(sourceImage, for: [candidate])
            await present(.eventReviewEdit(candidate.toPencildEvent()))
        } catch {
            showToast(error.localizedDescription)
        }
    }

    /// Opens History & Archive, which lives under the Agenda tab.
    func openHistory() {
        selectedTab = .agenda
        showHistory = true
    }

    /// Scans every source in one sequential batch, then presents the combined review session.
    /// A single-selection batch still uses this path, so progress and routing stay identical.
    func startBatchScan(
        sources: [BatchScanSource],
        services: ServiceContainer,
        modelContext: ModelContext?
    ) async {
        guard !sources.isEmpty, !isBatchScanning else { return }
        let scanner = BatchScanViewModel(services: services)
        activeBatchScan = scanner
        isBatchScanning = true
        await scanner.scan(sources, modelContext: modelContext)
        isBatchScanning = false

        let session = BatchReviewSession(scan: scanner, services: services)
        // Out of free scans before finding anything: offer Plus instead of an empty review.
        if session.hitScanLimit && session.events.isEmpty {
            showToast(PlanLimits.scanLimitMessage)
            await present(.paywall(opening: .plus))
            return
        }
        if let feature = session.lockedFeature, session.events.isEmpty {
            showToast(feature.upgradeReason)
            await present(.paywall(for: feature))
            return
        }
        await presentBatchReview(session)
    }

    // Toast Feedback
    @Published var toastMessage: String? = nil

    private var snapshotSubscription: AnyCancellable?
    private let toastDismissalScheduler: any ToastDismissalScheduling

    init(toastDismissalScheduler: any ToastDismissalScheduling = LiveToastDismissalScheduler()) {
        self.toastDismissalScheduler = toastDismissalScheduler
    }

    /// Mirrors the entitlement snapshot. The live StoreKit service publishes changes (purchases,
    /// renewals, refunds, retries).
    func bind(subscription: SubscriptionServiceProtocol) {
        entitlementProvider = subscription
        entitlementSnapshot = subscription.entitlementSnapshot
        if let live = subscription as? SubscriptionService {
            snapshotSubscription = live.$entitlementSnapshot
                .receive(on: DispatchQueue.main)
                .sink { [weak self] snapshot in self?.entitlementSnapshot = snapshot }
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastDismissalScheduler.scheduleDismissal { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }

    func rememberSourceImage(_ image: UIImage?, for candidates: [EventCandidate]) {
        guard let image else { return }
        for candidate in candidates {
            sourceImages[candidate.id] = image
        }
    }

    func clearSourceImages() {
        sourceImages.removeAll()
        lastScanImage = nil
    }

    /// Opens the review screen for a scanned candidate.
    func review(_ candidate: EventCandidate) async {
        await present(.eventReviewEdit(candidate.toPencildEvent()))
    }

    /// Presents the batch review sheet, first dismissing any sheet already on screen.
    func presentBatchReview(_ session: BatchReviewSession) async {
        batchReviewSession = nil
        await dismissPresentedSheets()
        batchReviewSession = session
    }

    /// Opens the saved event (or its review, if not yet saved) a notification pointed at.
    func presentDeepLinkedEvent(_ candidate: EventCandidate) async {
        let event = candidate.toPencildEvent()
        await present(candidate.savedEvent?.status == .saved ? .savedEventDetail(event) : .eventReviewEdit(event))
    }

    /// Routes a finished scan to review, the no-dates recovery screen, or an error toast.
    /// Several events from one scan (a work schedule or multi-date flyer) open together in Batch Review.
    func handleScanOutcome(_ scan: ScanViewModel, services: ServiceContainer) async {
        switch scan.stage {
        case .complete(let candidates):
            rememberSourceImage(scan.currentProcessingImage, for: candidates)
            guard let first = candidates.first else { return }
            guard candidates.count > 1 else {
                await present(.eventReviewEdit(first.toPencildEvent()))
                return
            }
            let events = candidates.map { candidate in
                BatchEventItem(
                    candidate: candidate,
                    screenshotID: UUID(),
                    screenshotLabel: candidate.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                    screenshotImage: scan.currentProcessingImage,
                    services: services
                )
            }
            await presentBatchReview(BatchReviewSession(events: events))
        case .noDatesFound(let rawText):
            lastScanRawText = rawText
            lastScanImage = scan.currentProcessingImage
            await present(.noDatesFound)
        case .alreadySaved(let count):
            await dismissPresentedSheets()
            showToast(count == 1 ? "Already saved — find it in History" : "All \(count) events are already saved")
            openHistory()
        case .scanLimitReached:
            showToast(PlanLimits.scanLimitMessage)
            await present(.paywall(opening: .plus))
        case .requiresUpgrade(let feature):
            showToast(feature.upgradeReason)
            await present(.paywall(for: feature))
        case .failed(let message):
            await dismissPresentedSheets()
            showToast(message)
        default:
            break
        }
    }

    /// Dismisses the root modal sheet. A batch review session is left alone so its unsaved
    /// edits survive; Batch Review presents its own sheets from inside the session.
    private func dismissPresentedSheets() async {
        guard activeModal != nil else { return }
        activeModal = nil
        try? await Task.sleep(for: Self.sheetDismissalDelay)
    }
}
