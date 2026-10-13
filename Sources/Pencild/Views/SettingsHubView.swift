import SwiftUI

// MARK: - Settings Hub View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/design.html`.
/// Root of the Settings cluster with navigation to sub-screens, permissions inspection, and StoreKit controls.
struct SettingsHubView: View {
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var purchases = PurchaseViewModel()

    @AppStorage("settings.automaticCaptureEnabled") private var autoCaptureEnabled = true
    @State private var store = DefaultCalendarStore()
    @State private var restoring = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var photosStatus = PermissionLabel(text: "Checking…", granted: false)
    @State private var calendarStatus = PermissionLabel(text: "Checking…", granted: false)
    @State private var notificationsStatus = PermissionLabel(text: "Checking…", granted: false)

    private var tier: SubscriptionTier { appState.subscriptionTier }

    struct PermissionLabel: Equatable {
        var text: String
        var granted: Bool
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                headerBar
                screenIntro
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 20) {
                            subscriptionSection
                            permissionsSection
                        }
                        VStack(spacing: 20) {
                            defaultsSection
                            privacySection
                            supportSection
                        }
                    }
                } else {
                    subscriptionSection
                    permissionsSection
                    defaultsSection
                    privacySection
                    supportSection
                }
                versionFooter
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 1120 : .infinity)
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .frame(maxWidth: .infinity)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .task { await purchases.attach(services.subscription) }
        .task(id: scenePhase) { await refreshPermissions() }
    }

    // MARK: - Live permission state
    private func refreshPermissions() async {
        switch services.photoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: photosStatus = .init(text: "Full Access", granted: true)
        case .limited: photosStatus = .init(text: "Limited", granted: true)
        case .notDetermined: photosStatus = .init(text: "Not Asked", granted: false)
        default: photosStatus = .init(text: "Off", granted: false)
        }
        switch services.calendar.authorizationStatus() {
        case .fullAccess: calendarStatus = .init(text: "Full Access", granted: true)
        case .writeOnly: calendarStatus = .init(text: "Add Only", granted: true)
        case .notDetermined: calendarStatus = .init(text: "Not Asked", granted: false)
        default: calendarStatus = .init(text: "Off", granted: false)
        }
        switch await services.notifications.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: notificationsStatus = .init(text: "On", granted: true)
        case .notDetermined: notificationsStatus = .init(text: "Not Asked", granted: false)
        default: notificationsStatus = .init(text: "Off", granted: false)
        }
    }

    private var planSummary: String {
        switch tier {
        case .starter: return "Upgrade to Plus for auto-detect and unlimited screenshot scans."
        case .plus: return "Plus includes unlimited screenshot scans and multi-stage reminders. Renewal details are in Manage Plan."
        case .premium: return "Premium adds PDF import, multi-page documents and batch scanning. Renewal details are in Manage Plan."
        }
    }

    // MARK: - Subviews

    private var headerBar: some View {
        PDTopBar(title: "Settings", showsBack: false) {
            Button {
                navigate(.userProfile)
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pdOnPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.pdPrimary))
                    .contentShape(Circle())
            }
            .accessibilityLabel("Profile")
        }
    }

    private var screenIntro: some View {
        PDScreenIntro(
            eyebrow: "Settings",
            title: "Settings",
            subtitle: "Manage permissions, default calendars, reminder rules, and Pencil’d Pro subscription."
        )
    }

    private var subscriptionSection: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top) {
                    HStack(spacing: 12) {
                        PDIconTile(systemName: "sparkles", tint: .pdPrimary, size: .large)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier == .starter ? "Pencil’d Free" : "Pencil’d \(tier.displayName)")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                            Text(tier == .starter ? "Free plan" : "Subscription active")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }

                    Spacer()

                    PDStatusBadge(
                        text: tier == .starter ? "FREE" : "ACTIVE",
                        tone: tier == .starter ? .neutral : .success
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pdPrimary)
                    Text(planSummary)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceHighest.opacity(0.6)))

                VStack(spacing: 8) {
                    Button {
                        navigate(.managePlan)
                    } label: {
                        HStack {
                            Text(tier == .starter ? "See plans" : "Manage Subscription")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(PDGradientButtonStyle())

                    Button {
                        restoring = true
                        Task {
                            let restored = await purchases.restore()
                            restoring = false
                            if let restored {
                                appState.showToast(restored == .starter ? "No prior subscription found" : "✓ \(restored.displayName) restored")
                            }
                        }
                    } label: {
                        Text(restoring ? "Restoring..." : "Restore purchases")
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdPrimary)
                    }
                    .disabled(restoring)
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "System Permissions")

            PDGroupedList {
                permissionRow(
                    icon: "photo.stack.fill",
                    iconColor: .pdPrimary,
                    title: "Photos",
                    subtitle: "Detection & crop bounds",
                    status: photosStatus.text,
                    granted: photosStatus.granted
                )
                PDRowDivider()
                permissionRow(
                    icon: "calendar",
                    iconColor: .pdSecondary,
                    title: "Calendar",
                    subtitle: "Direct schedule writes",
                    status: calendarStatus.text,
                    granted: calendarStatus.granted
                )
                PDRowDivider()
                permissionRow(
                    icon: "bell.badge.fill",
                    iconColor: .pdTertiaryContainer,
                    title: "Notifications",
                    subtitle: "Capture summaries & alerts",
                    status: notificationsStatus.text,
                    granted: notificationsStatus.granted
                )
            }
        }
    }

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "App Defaults")

            PDGroupedList {
                Button {
                    navigate(.defaultCalendar)
                } label: {
                    PDListRow(
                        icon: "calendar.badge.checkmark",
                        tint: .pdPrimary,
                        title: "Default Calendar"
                    ) {
                        PDValueChevron(value: store.defaultCalendarTitle() ?? "iOS default")
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button {
                    navigate(.reminderSettings)
                } label: {
                    PDListRow(
                        icon: "alarm.fill",
                        tint: .pdSecondary,
                        title: "Default Reminders"
                    ) {
                        PDValueChevron(value: "Smart, by event type")
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button {
                    navigate(.automationSettings)
                } label: {
                    PDListRow(
                        icon: "camera.filters",
                        tint: .pdTertiaryContainer,
                        title: "Source Preferences"
                    ) {
                        PDValueChevron(value: "Screenshots, PDFs, Photos")
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                PDToggleRow(
                    icon: "arrow.triangle.2.circlepath",
                    tint: .pdPrimary,
                    title: "Automatic Capture",
                    subtitle: autoCaptureEnabled ? "Background photo scan on" : "Background photo scan off",
                    isOn: $autoCaptureEnabled
                )
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Privacy & Security")

            PDCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        PDIconTile(systemName: "lock.fill", tint: .pdPrimary)
                        Text("On-Device Privacy First")
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdOnSurface)
                    }

                    Text("Pencil’d analyzes your photos and screenshots locally on your device neural engine. Scanned images are never stored or transmitted to external servers.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineSpacing(2)

                    Button {
                        navigate(.privacyCenter)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Learn how Pencil'd handles scans")
                            Image(systemName: "arrow.right")
                        }
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdPrimary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Support & Legal")

            PDGroupedList {
                Button {
                    navigate(.helpFeedback)
                } label: {
                    PDListRow(
                        icon: "questionmark.circle.fill",
                        tint: .pdOnSurfaceVariant,
                        title: "Help & Support Guide"
                    ) {
                        PDValueChevron()
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                #if DEBUG
                PDRowDivider()
                Button {
                    navigate(.marketingKit)
                } label: {
                    PDListRow(
                        icon: "megaphone.fill",
                        tint: .pdPrimary,
                        title: "Marketing Kit"
                    ) {
                        PDValueChevron()
                    }
                }
                .buttonStyle(PDRowButtonStyle())
                #endif

                PDRowDivider()

                Button {
                    openURL(PencildLinks.termsOfUse)
                } label: {
                    PDListRow(
                        icon: "doc.text.fill",
                        tint: .pdOnSurfaceVariant,
                        title: "Terms of Service"
                    ) {
                        PDValueChevron()
                    }
                }
                .buttonStyle(PDRowButtonStyle())

                PDRowDivider()

                Button {
                    openURL(PencildLinks.privacyPolicy)
                } label: {
                    PDListRow(
                        icon: "shield.fill",
                        tint: .pdOnSurfaceVariant,
                        title: "Privacy Policy"
                    ) {
                        PDValueChevron()
                    }
                }
                .buttonStyle(PDRowButtonStyle())
            }
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Pencil’d for iOS v\(appVersion)")
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, PDSpacing.xs)
        .padding(.bottom, PDSpacing.xl)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (Build \(build))"
    }

    private func navigate(_ route: SettingsRoute) {
        settings.pendingRoute = route
    }

    private func permissionRow(icon: String, iconColor: Color, title: String, subtitle: String, status: String, granted: Bool) -> some View {
        PDListRow(
            icon: icon,
            tint: iconColor,
            title: title,
            subtitle: subtitle
        ) {
            HStack(spacing: 8) {
                PDStatusBadge(
                    text: status,
                    icon: granted ? "checkmark" : nil,
                    tone: granted ? .success : .warning
                )
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pdOutline)
            }
        }
    }
}

typealias SettingsRowButtonStyle = PDRowButtonStyle
