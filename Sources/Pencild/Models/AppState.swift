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
    case premiumPaywall
    case plusPaywall
    case calendarPermissionDenied
    case notificationPermissionDenied
    case noDatesFound
    case savedEventDetail(PencildEvent)
    case eventReviewEdit(PencildEvent)
    case reminderScheduleEditor(PencildEvent)
    case recentScreenshots
    case screenGallery
    case userProfile
    case defaultCalendar
    
    var id: String {
        switch self {
        case .premiumPaywall: return "premiumPaywall"
        case .plusPaywall: return "plusPaywall"
        case .calendarPermissionDenied: return "calendarPermissionDenied"
        case .notificationPermissionDenied: return "notificationPermissionDenied"
        case .noDatesFound: return "noDatesFound"
        case .savedEventDetail(let event): return "savedEventDetail-\(event.id)"
        case .eventReviewEdit(let event): return "eventReviewEdit-\(event.id)"
        case .reminderScheduleEditor(let event): return "reminderScheduleEditor-\(event.id)"
        case .recentScreenshots: return "recentScreenshots"
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
    @Published private(set) var subscriptionTier: SubscriptionTier = .starter
    var isPlusMember: Bool { subscriptionTier != .starter }
    var isPremiumMember: Bool { subscriptionTier == .premium }

    func isEntitled(to feature: PremiumFeature) -> Bool {
        subscriptionTier.includes(feature)
    }

    // Scan context handed from the scan pipeline to the review / no-dates screens.
    @Published var lastScanRawText: String = ""
    @Published var lastScanImage: UIImage? = nil
    /// Source images keyed by candidate id, so the review screen can show what was scanned this session.
    private(set) var sourceImages: [String: UIImage] = [:]
    /// Set by "Scan another photo" flows to reopen the photo picker from Home.
    @Published var requestPhotoPicker: Bool = false
    @Published var requestFileImporter: Bool = false
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
        await dismissPresentedSheets()
        activeModal = modal
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
            await present(.plusPaywall)
            return
        }
        if let feature = session.lockedFeature, session.events.isEmpty {
            showToast(feature.upgradeReason)
            await present(feature.requiredTier == .premium ? .premiumPaywall : .plusPaywall)
            return
        }
        await presentBatchReview(session)
    }

    // Toast Feedback
    @Published var toastMessage: String? = nil

    private var tierSubscription: AnyCancellable?
    private let toastDismissalScheduler: any ToastDismissalScheduling

    init(toastDismissalScheduler: any ToastDismissalScheduling = LiveToastDismissalScheduler()) {
        self.toastDismissalScheduler = toastDismissalScheduler
    }

    /// Mirrors the subscription tier. The live StoreKit service publishes changes (purchases, renewals, refunds).
    func bind(subscription: SubscriptionServiceProtocol) {
        subscriptionTier = subscription.currentTier
        if let live = subscription as? SubscriptionService {
            tierSubscription = live.$currentTier
                .receive(on: DispatchQueue.main)
                .sink { [weak self] tier in self?.subscriptionTier = tier }
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
            await present(.plusPaywall)
        case .requiresUpgrade(let feature):
            showToast(feature.upgradeReason)
            await present(feature.requiredTier == .premium ? .premiumPaywall : .plusPaywall)
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
