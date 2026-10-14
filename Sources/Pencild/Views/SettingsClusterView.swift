import SwiftUI

// Routes inside the Settings cluster's navigation stack.
enum SettingsRoute: String, CaseIterable {
    case userProfile
    case defaultCalendar
    case managePlan
    #if DEBUG
    case marketingKit
    #endif
    case privacyCenter
    case automationSettings
    case reminderSettings
    case helpFeedback
}

// Container for the Settings tab: a navigation stack rooted at the hub,
// with deep-link support so the Screen Gallery can jump straight to any
// screen via SettingsState.pendingRoute.
struct SettingsClusterView: View {
    @EnvironmentObject private var settings: SettingsState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SettingsHubView()
                // Every screen draws its own PDTopBar; the system bar would add a second back button.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: SettingsRoute.self) { route in
                    destination(for: route)
                        .toolbar(.hidden, for: .navigationBar)
                        .environment(\.pdBackLabel, "Settings")
                }
        }
        .onChange(of: settings.pendingRoute) { _, newValue in
            guard let route = newValue else { return }
            settings.pendingRoute = nil
            path.append(route)
        }
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute) -> some View {
        switch route {
        case .userProfile: UserProfileFlowView()
        case .defaultCalendar: DefaultCalendarView()
        case .managePlan: ManagePlanView()
        #if DEBUG
        case .marketingKit: MarketingKitView()
        #endif
        case .privacyCenter: PrivacyCenterView()
        case .automationSettings: AutomationSettingsView()
        case .reminderSettings: ReminderSettingsView()
        case .helpFeedback: HelpFeedbackView()
        }
    }
}
