import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var appState = AppState()
    @StateObject private var settingsState = SettingsState()
    @StateObject private var scanViewModel: ScanViewModel
    @StateObject private var homeViewModel: HomeViewModel

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
                case .review:
                    ReviewQueueView()
                case .history:
                    HistoryArchiveView()
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
            .padding(.bottom, 6)
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
            .environment(\.services, services)
        }
        .onAppear {
            appState.bind(subscription: services.subscription)
            openPendingDeepLink()
        }
        .onReceive(NotificationCenter.default.publisher(for: DeepLinkInbox.notificationName)) { _ in
            openPendingDeepLink()
        }
        .onChange(of: scenePhase) { _, phase in
            // Returning from iOS Settings (or anywhere else): re-read permission state.
            if phase == .active {
                homeViewModel.refreshStatus()
            }
        }
    }

    /// Opens the saved event a notification tap pointed at.
    private func openPendingDeepLink() {
        guard let eventId = DeepLinkInbox.shared.consume() else { return }
        guard let candidate = SavedEventActions.candidate(id: eventId, in: modelContext) else {
            appState.showToast("That event is no longer in DateSnap")
            return
        }
        let event = candidate.toDateSnapEvent()
        appState.activeModal = nil
        // Let any presented sheet dismiss before presenting the detail.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            appState.activeModal = candidate.savedEvent?.status == .saved ? .savedEventDetail(event) : .eventReviewEdit(event)
        }
    }
    
    // MARK: - Custom Glassmorphic Tab Bar
    private var customTabBar: some View {
        HStack {
            ForEach(ActiveTab.allCases) { tab in
                let isSelected = appState.selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        Text(tab.rawValue)
                            .font(DSTypography.caption())
                            .fontWeight(isSelected ? .bold : .medium)
                    }
                    .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isSelected ? Color.dsPrimary.opacity(0.12) : Color.clear)
                    )
                }
            }
            
            #if DEBUG
            // Screen Gallery / Direct Switcher Button
            Button {
                appState.activeModal = .screenGallery
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("Screens")
                        .font(DSTypography.caption())
                        .fontWeight(.bold)
                }
                .foregroundStyle(Color.dsAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.dsAccent.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.dsAccent.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            #endif
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color(hex: "0A0E1E").opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.dsBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 16, y: 8)
        )
        .padding(.horizontal, 16)
    }
}