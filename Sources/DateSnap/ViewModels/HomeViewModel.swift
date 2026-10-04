import Foundation
import SwiftUI
import Photos
import EventKit
import UserNotifications

@MainActor
public final class HomeViewModel: ObservableObject {
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let subscriptionService: SubscriptionServiceProtocol
    private let calendarService: CalendarServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let ocrService: OCRServiceProtocol

    // MARK: - Published State
    @Published public var recentScreenshots: [PHAsset] = []
    @Published public var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public var isCalendarAuthorized: Bool = false
    @Published public var isNotificationsAuthorized: Bool = false
    @Published public var currentSubscriptionTier: SubscriptionTier = .starter
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String? = nil
    /// Screenshots the Plus triage judged likely to contain an event.
    @Published public var likelyEventIDs: Set<String> = []
    /// Screenshots already checked by triage (so each is assessed once per session).
    private var assessedIDs: Set<String> = []
    private var triageTask: Task<Void, Never>? = nil

    private var observationTask: Task<Void, Never>? = nil

    public init(services: ServiceContainer) {
        self.photoLibraryService = services.photoLibrary
        self.subscriptionService = services.subscription
        self.calendarService = services.calendar
        self.notificationService = services.notifications
        self.ocrService = services.ocr

        refreshStatus()
        startObservingPhotoLibrary()
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Permissions & Status Refresh
    public func refreshStatus() {
        self.photoAuthorizationStatus = photoLibraryService.authorizationStatus(for: .readWrite)
        let calStatus = calendarService.authorizationStatus()
        if #available(iOS 17.0, *) {
            self.isCalendarAuthorized = (calStatus == .fullAccess)
        } else {
            self.isCalendarAuthorized = (calStatus == .authorized)
        }
        self.currentSubscriptionTier = subscriptionService.currentTier

        Task {
            let notifStatus = await notificationService.authorizationStatus()
            self.isNotificationsAuthorized = (notifStatus == .authorized || notifStatus == .provisional)
        }

        if photoAuthorizationStatus == .authorized || photoAuthorizationStatus == .limited {
            _ = loadAutomaticallyDetectedScreenshots()
        }
    }

    // MARK: - Request Permissions
    public func requestPhotoAccess() async {
        let status = await photoLibraryService.requestAuthorization(for: .readWrite)
        self.photoAuthorizationStatus = status
        if status == .authorized || status == .limited {
            loadRecentScreenshots()
        }
    }

    /// Ensures Photo Library read access, prompting the first time. Returns false when denied or restricted.
    public func ensurePhotoAccess() async -> Bool {
        switch photoLibraryService.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            photoAuthorizationStatus = photoLibraryService.authorizationStatus(for: .readWrite)
            return true
        case .notDetermined:
            await requestPhotoAccess()
            return photoAuthorizationStatus == .authorized || photoAuthorizationStatus == .limited
        default:
            photoAuthorizationStatus = photoLibraryService.authorizationStatus(for: .readWrite)
            return false
        }
    }

    public func requestCalendarAccess() async -> Bool {
        do {
            let granted = try await calendarService.requestEventAccess()
            self.isCalendarAuthorized = granted
            return granted
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func requestNotificationAccess() async -> Bool {
        do {
            let granted = try await notificationService.requestAuthorization()
            self.isNotificationsAuthorized = granted
            return granted
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Load Screenshots
    public func loadRecentScreenshots(limit: Int = 10) {
        guard photoAuthorizationStatus == .authorized || photoAuthorizationStatus == .limited else {
            return
        }

        isRefreshing = true
        Task {
            do {
                let assets = try await photoLibraryService.fetchRecentScreenshots(limit: limit)
                self.recentScreenshots = assets
                self.isRefreshing = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isRefreshing = false
            }
        }
    }

    /// Automatic library monitoring is a Plus operation; manual user-initiated loading remains available.
    @discardableResult
    public func loadAutomaticallyDetectedScreenshots(limit: Int = 10) -> FeatureAccessDecision {
        let decision = FeatureAccessPolicy.decision(
            for: .automaticScreenshotDetection,
            snapshot: subscriptionService.entitlementSnapshot
        )
        guard decision == .allowed else { return decision }
        loadRecentScreenshots(limit: limit)
        return .allowed
    }

    // MARK: - Likely-Event Triage (Plus)
    /// Checks up to `PhotoCandidateRanker.assessmentBudget` new, unscanned screenshots on device.
    @discardableResult
    public func triageLikelyEvents(scannedIDs: Set<String>) -> FeatureAccessDecision {
        let snapshot = subscriptionService.entitlementSnapshot
        let decision = FeatureAccessPolicy.decision(for: .likelyEventTriage, snapshot: snapshot)
        guard decision == .allowed else { return decision }
        guard triageTask == nil else { return .allowed }
        let candidates = recentScreenshots
            .filter { !scannedIDs.contains($0.localIdentifier) && !assessedIDs.contains($0.localIdentifier) }
            .prefix(PhotoCandidateRanker.assessmentBudget)
        let granted = IntelligenceUsagePolicy().consume(.likelyEventTriage, count: candidates.count, tier: snapshot.tier)
        let pending = candidates.prefix(granted)
        guard !pending.isEmpty else { return .allowed }
        let photos = photoLibraryService
        let ocr = ocrService
        triageTask = Task { [weak self] in
            await withTaskGroup(of: (String, Bool).self) { group in
                for asset in pending {
                    guard !Task.isCancelled else { break }
                    let assetID = asset.localIdentifier
                    group.addTask {
                        let likely = await PhotoCandidateRanker.isLikelyEvent(asset, photos: photos, ocr: ocr)
                        return (assetID, likely)
                    }
                }
                for await (assetID, likely) in group {
                    guard let self = self, !Task.isCancelled else { break }
                    self.assessedIDs.insert(assetID)
                    if likely { self.likelyEventIDs.insert(assetID) }
                }
            }
            self?.triageTask = nil
        }
        return .allowed
    }

    // MARK: - Observe Photo Library Changes
    private func startObservingPhotoLibrary() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = self.photoLibraryService.observeLibraryChanges()
            for await _ in stream {
                guard !Task.isCancelled else { break }
                // Best-effort automatic reload of recent screenshots when active
                _ = self.loadAutomaticallyDetectedScreenshots()
            }
        }
    }
}
