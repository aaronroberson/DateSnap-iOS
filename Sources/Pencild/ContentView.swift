import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            if horizontalSizeClass == .regular {
                HStack(spacing: 0) {
                    iPadNavigationRail
                    Rectangle()
                        .fill(Color.pdOutlineVariant.opacity(0.45))
                        .frame(width: 1)
                    selectedScreen
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color.pdSurface.ignoresSafeArea())
                .overlay(alignment: .bottomTrailing) {
                    if let toast = appState.toastMessage {
                        toastBanner(toast)
                            .padding(.trailing, 24)
                            .padding(.bottom, 18)
                    }
                }
            } else {
                selectedScreen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 8) {
                    if let toast = appState.toastMessage {
                        toastBanner(toast)
                    }
                    customTabBar
                }
            }
        }
        .disabled(scanViewModel.isProcessing || appState.isBatchScanning)
        .accessibilityHidden(scanViewModel.isProcessing || appState.isBatchScanning)
        .overlay {
            ScanProgressOverlay(scan: scanViewModel)
            BatchScanProgressOverlay()
        }
        .overlay {
            if showSplash {
                PencilSplashView(
                    onFinish: { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { showSplash = false } },
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
                case .userProfile:
                    UserProfileFlowView()
                case .defaultCalendar:
                    DefaultCalendarView()
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

    @ViewBuilder
    private var selectedScreen: some View {
        switch appState.selectedTab {
        case .home: HomeEmptyStateView()
        case .agenda:
            NavigationStack {
                AgendaView()
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(isPresented: $appState.showHistory) {
                        HistoryArchiveView()
                            .toolbar(.hidden, for: .navigationBar)
                    }
            }
        case .review: ReviewQueueView()
        case .settings: SettingsClusterView()
        }
    }

    private var iPadNavigationRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient.pdSignature)
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "pencil.and.outline").foregroundStyle(Color.pdSurface))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Pencil'd")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pdOnSurface)
                    Text("SCANNED. REVIEWED.")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 22)

            ForEach(ActiveTab.allCases) { tab in
                let isSelected = appState.selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = tab }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                            .frame(width: 24)
                        Text(tab.rawValue)
                            .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                        Spacer(minLength: 0)
                        if isSelected {
                            Capsule().fill(Color.pdOrange).frame(width: 3, height: 24)
                        }
                    }
                    .foregroundStyle(isSelected ? Color.pdOrange : Color.pdOnSurfaceVariant)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .frame(height: 52)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.pdPrimary.opacity(0.12))
                                .padding(.horizontal, 8)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("navigation.\(tab.id.lowercased())")
            }

            Spacer(minLength: 20)
            Label("Private, on-device processing", systemImage: "lock.shield.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
        }
        .frame(width: 232)
        .frame(maxHeight: .infinity)
        .background(Color.pdSurfaceLowest)
    }

    private func toastBanner(_ toast: String) -> some View {
        HStack(spacing: PDSpacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.pdPrimary)
            Text(toast)
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurface)
                .lineLimit(2)
        }
        .padding(.horizontal, PDSpacing.md)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.pdSurfaceContainerHigh.opacity(0.92))
                .overlay(Capsule().stroke(Color.pdPrimary.opacity(0.4), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .accessibilityIdentifier("navigation.\(tab.id.lowercased())")
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
