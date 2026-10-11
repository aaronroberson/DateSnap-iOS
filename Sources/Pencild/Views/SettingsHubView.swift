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
            }
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
                        Text("Pencil’d Pro")
                            .font(DSTypography.headlineCard())
                            .foregroundStyle(Color.dsForeground)
                        Text("Annual Plan • Auto-Renews")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle().fill(Color.dsSecondary).frame(width: 5, height: 5)
                    Text("ACTIVE")
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
                Text("Renews Oct 28, 2027 • Unlimited OCR & Multi-Event Detection")
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
                        Text("Manage Subscription")
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
                    status: "Full Access",
                    statusColor: .dsPrimary
                )
                Divider().overlay(Color.dsBorder)
                permissionRow(
                    icon: "calendar",
                    iconColor: .dsSecondary,
                    title: "Calendar",
                    subtitle: "Direct schedule writes",
                    status: "Read & Write",
                    statusColor: .dsSecondary
                )
                Divider().overlay(Color.dsBorder)
                permissionRow(
                    icon: "bell.badge.fill",
                    iconColor: .dsAccent,
                    title: "Notifications",
                    subtitle: "Capture summaries & alerts",
                    status: "Banners & Sounds",
                    statusColor: .dsAccent
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
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    navigate(.reminderSettings)
                } label: {
                    appDefaultRow(
                        icon: "alarm.fill",
                        iconColor: .dsSecondary,
                        title: "Default Reminders",
                        value: "2h before, 1d before"
                    )
                }
                .buttonStyle(.plain)

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
                .buttonStyle(.plain)

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
                        Text("Background photo scan enabled")
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
                .buttonStyle(.plain)

                #if DEBUG
                Divider().overlay(Color.dsBorder)
                Button {
                    navigate(.marketingKit)
                } label: {
                    supportRow(icon: "megaphone.fill", title: "Marketing Kit")
                }
                .buttonStyle(.plain)
                #endif

                Divider().overlay(Color.dsBorder)

                Button {
                    openURL(PencildLinks.termsOfUse)
                } label: {
                    supportRow(icon: "doc.text.fill", title: "Terms of Service")
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    openURL(PencildLinks.privacyPolicy)
                } label: {
                    supportRow(icon: "shield.fill", title: "Privacy Policy")
                }
                .buttonStyle(.plain)
            }
            .dsGlassCard()
        }
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Pencil’d for iOS v\(appVersion) • Designed for iOS 18")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.4.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "412"
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
