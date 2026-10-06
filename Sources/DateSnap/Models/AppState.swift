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
    case review = "Review"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home: return "viewfinder"
        case .review: return "sparkles"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape.fill"
        }
    }
}

enum AppModalScreen: Identifiable, Sendable {
    case premiumPaywall
    case plusPaywall
    case calendarPermissionDenied
    case notificationPermissionDenied
    case noDatesFound
    case savedEventDetail(DateSnapEvent)
    case eventReviewEdit(DateSnapEvent)
    case reminderScheduleEditor(DateSnapEvent)
    case recentScreenshots
    case screenGallery
    
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
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: ActiveTab = .home
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
    /// Multi-screenshot batch session; presented as its own sheet with per-event destinations.
    @Published var batchReviewSession: BatchReviewSession? = nil
    /// In-flight multi-screenshot scan, kept here so progress survives picker dismissal.
    @Published private(set) var activeBatchScan: BatchScanViewModel? = nil
    @Published private(set) var isBatchScanning = false

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
    func review(_ candidate: EventCandidate) {
        activeModal = .eventReviewEdit(candidate.toDateSnapEvent())
    }

    /// Presents the batch review sheet, first dismissing any sheet already on screen.
    func presentBatchReview(_ session: BatchReviewSession) async {
        batchReviewSession = nil
        if activeModal != nil {
            activeModal = nil
            try? await Task.sleep(for: .milliseconds(400))
        }
        batchReviewSession = session
    }
}
