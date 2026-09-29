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

    // MARK: - Published State
    @Published public var recentScreenshots: [PHAsset] = []
    @Published public var photoAuthorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published public var isCalendarAuthorized: Bool = false
    @Published public var isNotificationsAuthorized: Bool = false
    @Published public var currentSubscriptionTier: SubscriptionTier = .starter
    @Published public var isRefreshing: Bool = false
    @Published public var errorMessage: String? = nil

    private var observationTask: Task<Void, Never>? = nil

    public init(services: ServiceContainer) {
        self.photoLibraryService = services.photoLibrary
        self.subscriptionService = services.subscription
        self.calendarService = services.calendar
        self.notificationService = services.notifications

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
            loadRecentScreenshots()
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

    // MARK: - Observe Photo Library Changes
    private func startObservingPhotoLibrary() {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self = self else { return }
            let stream = self.photoLibraryService.observeLibraryChanges()
            for await _ in stream {
                guard !Task.isCancelled else { break }
                // Best-effort automatic reload of recent screenshots when active
                self.loadRecentScreenshots()
            }
        }
    }
}
