import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @StateObject private var appState = AppState()
    @StateObject private var settingsState = SettingsState()
    @StateObject private var scanViewModel: ScanViewModel
    @StateObject private var homeViewModel: HomeViewModel
    @Query private var candidates: [EventCandidate]
    @State private var showSplash = true

    init(services: ServiceContainer) {
        _scanViewModel = StateObject(wrappedValue: ScanViewModel(services: services))
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(services: services))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Tab Content
            Group {
                switch appState.selectedTab {
                case .home:
                    HomeEmptyStateView()
                case .agenda:
                    NavigationStack {
                        AgendaView()
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(isPresented: $appState.showHistory) {
                                HistoryArchiveView()
                                    .toolbar(.hidden, for: .navigationBar)
                            }
                    }
                case .review:
                    ReviewQueueView()
                case .settings:
                    SettingsClusterView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Glassmorphic Tab Bar & Quick Switcher
            VStack(spacing: 8) {
                // Toast notification banner if active
                if let toast = appState.toastMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.dsPrimary)
                        Text(toast)
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.dsCardElevated)
                            .overlay(Capsule().stroke(Color.dsPrimary.opacity(0.6), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                // Custom Branded Tab Bar
                customTabBar
            }
        }
        .overlay {
            if showSplash {
                PencilSplashView(
                    onFinish: { withAnimation(.easeInOut(duration: 0.4)) { showSplash = false } },
                    onScan: { appState.requestPhotoPicker = true },
                    onImport: { appState.requestFileImporter = true },
                    onReview: { appState.selectedTab = .review }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environmentObject(appState)
        .environmentObject(settingsState)
        .environmentObject(scanViewModel)
        .environmentObject(homeViewModel)
        .sheet(item: $appState.activeModal) { modal in
            Group {
                switch modal {
                case .premiumPaywall:
                    PremiumPaywallView()
                case .plusPaywall:
                    PlusPaywallView()
                case .calendarPermissionDenied:
                    CalendarPermissionDeniedView()
                case .notificationPermissionDenied:
                    NotificationPermissionDeniedView()
                case .noDatesFound:
                    NoDatesFoundView()
                case .savedEventDetail(let event):
                    SavedEventDetailView(event: event)
                case .eventReviewEdit(let event):
                    EventReviewEditView(event: event)
                case .reminderScheduleEditor(let event):
                    SavedEventScheduleEditor(event: event)
                case .recentScreenshots:
                    RecentScreenshotsView()
                case .screenGallery:
                    #if DEBUG
                    ScreenGalleryView()
                    #else
                    EmptyView()
                    #endif
                }
            }
            .environmentObject(appState)
            .environmentObject(settingsState)
            .environmentObject(scanViewModel)
            .environmentObject(homeViewModel)
            .pencildServices(services)
        }
        .sheet(item: $appState.batchReviewSession) { session in
            BatchReviewView(session: session)
                .environmentObject(appState)
                .environmentObject(settingsState)
                .environmentObject(scanViewModel)
                .environmentObject(homeViewModel)
                .pencildServices(services)
        }
        .onAppear {
            appState.bind(subscription: services.subscription)
            openPendingDeepLink()
        }
        .onReceive(NotificationCenter.default.publisher(for: DeepLinkInbox.notificationName)) { _ in
            openPendingDeepLink()
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning from iOS Settings (or anywhere else): re-read permission state
            // and re-resolve entitlements (purchases made or expired while backgrounded).
            if phase == .active {
                homeViewModel.refreshStatus()
                Task { await services.subscription.refreshEntitlements(.sceneActivation) }
            }
        }
    }

    /// Opens the saved event a notification tap pointed at.
    private func openPendingDeepLink() {
        if let url = DeepLinkInbox.shared.consumeURL() {
            openURL(url)
            return
        }
        guard let eventId = DeepLinkInbox.shared.consume() else { return }
        guard let candidate = SavedEventActions.candidate(id: eventId, in: modelContext) else {
            appState.showToast("That event is no longer in Pencil'd")
            return
        }
        let event = candidate.toPencildEvent()
        appState.activeModal = nil
        // Let any presented sheet dismiss before presenting the detail.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            appState.activeModal = candidate.savedEvent?.status == .saved ? .savedEventDetail(event) : .eventReviewEdit(event)
        }
    }
    
    /// Candidates waiting on the user, same definition as the Review tab.
    private var needsReview: Bool {
        candidates.contains { $0.savedEvent == nil || $0.savedEvent?.status == .draft }
    }

    // MARK: - Docked Tab Bar (Stitch bottom nav)
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(ActiveTab.allCases) { tab in
                let isSelected = appState.selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                            .overlay(alignment: .topTrailing) {
                                if tab == .review && needsReview {
                                    Circle()
                                        .fill(Color.pdTertiaryContainer)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 5, y: -2)
                                }
                            }
                        Text(tab.rawValue)
                            .font(PDFont.jakarta(11, isSelected ? .bold : .medium, relativeTo: .caption2))
                    }
                    .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant.opacity(0.7))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .overlay(alignment: .top) {
                        if isSelected {
                            Capsule()
                                .fill(Color.pdPrimary)
                                .frame(width: 32, height: 4)
                                .shadow(color: Color.pdPrimaryContainer.opacity(0.8), radius: 6)
                                .offset(y: -6)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityValue(tab == .review && needsReview ? "Items waiting" : "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.pdSurface.opacity(0.9))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.pdSurfaceHighest.opacity(0.6)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
