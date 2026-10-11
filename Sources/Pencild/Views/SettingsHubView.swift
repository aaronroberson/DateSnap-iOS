import SwiftUI

// MARK: - Settings Hub View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/design.html`.
/// Root of the Settings cluster with navigation to sub-screens, permissions inspection, and StoreKit controls.
struct SettingsHubView: View {
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
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
            VStack(alignment: .leading, spacing: 20) {
                headerBar
                screenIntro
                subscriptionSection
                permissionsSection
                defaultsSection
                privacySection
                supportSection
                versionFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .dsScreenBackground()
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
        HStack {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.dsBrandGradient)
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: "pencil.and.outline").font(.system(size: 15)).foregroundStyle(Color.dsBackground))
                Text("Settings")
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
            }

            Spacer()

            Button {
                navigate(.userProfile)
            } label: {
                Circle()
                    .fill(Color.dsPrimary)
                    .frame(width: 34, height: 34)
                    .overlay(Image(systemName: "person.fill").font(.system(size: 15)).foregroundStyle(Color.dsBackground))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Profile")
        }
        .padding(.top, 4)
    }

    private var screenIntro: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color.dsPrimary).frame(width: 6, height: 6)
                Text("SETTINGS")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsPrimary)
            }

            Text("Settings")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)

            Text("Manage permissions, default calendars, reminder rules, and Pencil’d Pro subscription.")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsMutedForeground)
                .lineSpacing(2)
        }
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsBrandGradient)
                            .frame(width: 42, height: 42)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tier == .starter ? "Pencil’d Free" : "Pencil’d \(tier.displayName)")
                            .font(DSTypography.headlineCard())
                            .foregroundStyle(Color.dsForeground)
                        Text(tier == .starter ? "Free plan" : "Subscription active")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color.dsSecondary).frame(width: 5, height: 5)
                    Text(tier == .starter ? "FREE" : "ACTIVE")
                        .font(DSTypography.overlineConfidence())
                        .foregroundStyle(Color.dsSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.dsSecondary.opacity(0.15)))
            }

            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.dsPrimary)
                Text(planSummary)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.dsSurfaceElevated))

            VStack(spacing: 8) {
                Button {
                    navigate(.managePlan)
                } label: {
                    HStack {
                        Text(tier == .starter ? "See plans" : "Manage Subscription")
                            .font(DSTypography.bodyStrong())
                            .foregroundStyle(Color.dsBackground)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.dsBackground)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 46)
                    .background(Capsule().fill(Color.dsBrandGradient))
                }

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
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsPrimary)
                }
                .disabled(restoring)
            }
        }
        .padding(16)
        .dsGlassCard()
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SYSTEM PERMISSIONS")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                permissionRow(
                    icon: "photo.stack.fill",
                    iconColor: .dsPrimary,
                    title: "Photos",
                    subtitle: "Detection & crop bounds",
                    status: photosStatus.text,
                    statusColor: photosStatus.granted ? .dsPrimary : .dsWarning
                )
                Divider().overlay(Color.dsBorder)
                permissionRow(
                    icon: "calendar",
                    iconColor: .dsSecondary,
                    title: "Calendar",
                    subtitle: "Direct schedule writes",
                    status: calendarStatus.text,
                    statusColor: calendarStatus.granted ? .dsSecondary : .dsWarning
                )
                Divider().overlay(Color.dsBorder)
                permissionRow(
                    icon: "bell.badge.fill",
                    iconColor: .dsAccent,
                    title: "Notifications",
                    subtitle: "Capture summaries & alerts",
                    status: notificationsStatus.text,
                    statusColor: notificationsStatus.granted ? .dsAccent : .dsWarning
                )
            }
            .dsGlassCard()
        }
    }

    private var defaultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("APP DEFAULTS")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                Button {
                    navigate(.defaultCalendar)
                } label: {
                    appDefaultRow(
                        icon: "calendar.badge.checkmark",
                        iconColor: .dsPrimary,
                        title: "Default Calendar",
                        value: store.defaultCalendarTitle() ?? "iOS default"
                    )
                }
                .buttonStyle(SettingsRowButtonStyle())

                Divider().overlay(Color.dsBorder)

                Button {
                    navigate(.reminderSettings)
                } label: {
                    appDefaultRow(
                        icon: "alarm.fill",
                        iconColor: .dsSecondary,
                        title: "Default Reminders",
                        value: "Smart, by event type"
                    )
                }
                .buttonStyle(SettingsRowButtonStyle())

                Divider().overlay(Color.dsBorder)

                Button {
                    navigate(.automationSettings)
                } label: {
                    appDefaultRow(
                        icon: "camera.filters",
                        iconColor: .dsAccent,
                        title: "Source Preferences",
                        value: "Screenshots, PDFs, Photos"
                    )
                }
                .buttonStyle(SettingsRowButtonStyle())

                Divider().overlay(Color.dsBorder)

                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.dsSurfaceElevated)
                        .frame(width: 32, height: 32)
                        .overlay(Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 14)).foregroundStyle(Color.dsPrimary))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic Capture")
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                        Text(autoCaptureEnabled ? "Background photo scan on" : "Background photo scan off")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }

                    Spacer()

                    Toggle("", isOn: $autoCaptureEnabled)
                        .labelsHidden()
                        .tint(Color.dsPrimary)
                }
                .padding(14)
            }
            .dsGlassCard()
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVACY & SECURITY")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.dsPrimary.opacity(0.15))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "lock.fill").font(.system(size: 13)).foregroundStyle(Color.dsPrimary))

                    Text("On-Device Privacy First")
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                }

                Text("Pencil’d analyzes your photos and screenshots locally on your device neural engine. Scanned images are never stored or transmitted to external servers.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .lineSpacing(2)

                Button {
                    navigate(.privacyCenter)
                } label: {
                    HStack(spacing: 4) {
                        Text("Learn how Pencil'd handles scans")
                        Image(systemName: "arrow.right")
                    }
                    .font(DSTypography.bodyCompact())
                    .foregroundStyle(Color.dsPrimary)
                }
                .padding(.top, 4)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUPPORT & LEGAL")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                Button {
                    navigate(.helpFeedback)
                } label: {
                    supportRow(icon: "questionmark.circle.fill", title: "Help & Support Guide")
                }
                .buttonStyle(SettingsRowButtonStyle())

                #if DEBUG
                Divider().overlay(Color.dsBorder)
                Button {
                    navigate(.marketingKit)
                } label: {
                    supportRow(icon: "megaphone.fill", title: "Marketing Kit")
                }
                .buttonStyle(SettingsRowButtonStyle())
                #endif

                Divider().overlay(Color.dsBorder)

                Button {
                    openURL(PencildLinks.termsOfUse)
                } label: {
                    supportRow(icon: "doc.text.fill", title: "Terms of Service")
                }
                .buttonStyle(SettingsRowButtonStyle())

                Divider().overlay(Color.dsBorder)

                Button {
                    openURL(PencildLinks.privacyPolicy)
                } label: {
                    supportRow(icon: "shield.fill", title: "Privacy Policy")
                }
                .buttonStyle(SettingsRowButtonStyle())
            }
            .dsGlassCard()
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Pencil’d for iOS v\(appVersion)")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (Build \(build))"
    }

    private func navigate(_ route: SettingsRoute) {
        settings.pendingRoute = route.rawValue
    }

    private func permissionRow(icon: String, iconColor: Color, title: String, subtitle: String, status: String, statusColor: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurfaceElevated)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(iconColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DSTypography.bodyCompact())
                    .foregroundStyle(Color.dsForeground)
                Text(subtitle)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }

            Spacer()

            Text(status)
                .font(DSTypography.labelChip())
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor.opacity(0.12)))

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
    }

    private func appDefaultRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurfaceElevated)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(iconColor))

            Text(title)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)

            Spacer()

            Text(value)
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
        .contentShape(Rectangle())
    }

    private func supportRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dsSurfaceElevated)
                .frame(width: 32, height: 32)
                .overlay(Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.dsMutedForeground))

            Text(title)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}


// MARK: - Settings Row Button Style
/// Makes the whole row (including empty space and padding) tappable, keeps a 52pt minimum
/// height, and shows press feedback so taps feel acknowledged.
struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.dsPrimary.opacity(0.12) : Color.clear)
    }
}
