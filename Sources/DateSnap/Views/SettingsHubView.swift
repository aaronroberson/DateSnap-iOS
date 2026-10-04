import SwiftUI

// Settings Hub — root of the Settings cluster. Rows navigate to working
// screens or invoke an explicit StoreKit action.
struct SettingsHubView: View {
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @StateObject private var purchases = PurchaseViewModel()
    @State private var restoring = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Settings Hub")
                profileCard
                sectionScanning
                sectionDestinations
                sectionPrivacy
                sectionBilling
                sectionSupport
                SettingsFooterNote(
                    lines: ["Version \(appVersion)", "Subscriptions are managed by the App Store"],
                    systemImage: "info.circle"
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .task { await purchases.attach(services.subscription) }
        .alert("Restore Failed", isPresented: Binding(
            get: { purchases.errorMessage != nil },
            set: { if !$0 { purchases.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(purchases.errorMessage ?? "")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    private var tierChipText: String {
        switch appState.subscriptionTier {
        case .starter: return "Free"
        case .plus: return "Plus"
        case .premium: return "Premium"
        }
    }

    // MARK: - Navigation helpers

    private func navigate(_ route: SettingsRoute) {
        settings.pendingRoute = route.rawValue
    }

    // MARK: - Profile

    private var profileCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.dsBrandGradient)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.dsMuted))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Your DateSnap")
                            .font(DSTypography.headlineCard())
                            .foregroundStyle(Color.dsForeground)
                        ValueChip(text: tierChipText, tint: .dsAccent, filled: true)
                    }
                    Text("No DateSnap account is required")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                Spacer()
            }
            .padding(16)

            Divider().overlay(Color.dsBorder)

            Button {
                navigate(.managePlan)
            } label: {
                SettingRow(icon: "checkmark.seal.fill", iconTint: .dsPrimary,
                           title: appState.subscriptionTier.displayName,
                           subtitle: "Tap to manage subscription") {
                    SettingsChevron()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.dsAccent2)
                Text("On-device scan and review")
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                Image(systemName: "iphone")
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.dsPrimary.opacity(0.05))
        }
        .dsGlassCard()
    }

    // MARK: - Scanning & Capture

    private var sectionScanning: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "camera.viewfinder", title: "Scanning",
                                  tint: .dsSecondary)
            VStack(spacing: 14) {
                Button {
                    navigate(.automationSettings)
                } label: {
                    SettingRow(icon: "wand.and.sparkles", iconTint: .dsSecondary,
                               title: "Enhanced Interpretation",
                               subtitle: "Optional Apple Intelligence help for ambiguous flyers") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Destinations & Reminders

    private var sectionDestinations: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "bell.badge.fill", title: "Reminders", tint: .dsPrimary)
            VStack(spacing: 14) {
                Button {
                    navigate(.reminderSettings)
                } label: {
                    SettingRow(icon: "bell.badge.fill", iconTint: .dsPrimary,
                               title: "Reminder Preview",
                               subtitle: "1 day before · 2 hours before") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Privacy & Security

    private var sectionPrivacy: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "lock.fill", title: "Privacy", tint: .dsError)
            VStack(spacing: 14) {
                Button {
                    navigate(.privacyCenter)
                } label: {
                    SettingRow(icon: "lock.iphone", iconTint: .dsSuccess,
                               title: "Privacy Center",
                               subtitle: "Clear stored scan text or erase DateSnap history") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Account & Billing

    private var sectionBilling: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "creditcard.fill", title: "Account & Billing", tint: .dsAccent)
            VStack(spacing: 14) {
                Button {
                    navigate(.managePlan)
                } label: {
                    SettingRow(icon: "crown.fill", iconTint: .dsWarning,
                               title: appState.subscriptionTier.displayName,
                               subtitle: "View available plans and manage billing") {
                        ValueChip(text: "Manage", tint: .dsSecondary)
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    restoring = true
                    Task {
                        let restored = await purchases.restore()
                        restoring = false
                        if let restored {
                            appState.showToast(restored == .starter ? "No active subscription found to restore" : "✓ \(restored.displayName) restored")
                        }
                    }
                } label: {
                    SettingRow(icon: "arrow.triangle.2.circlepath", iconTint: .dsInfo,
                               title: "Restore App Store Purchases",
                               subtitle: "Sync prior subscriptions via StoreKit") {
                        if restoring {
                            ProgressView().tint(Color.dsPrimary)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(restoring)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Support & System

    private var sectionSupport: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "questionmark.circle.fill", title: "Support & System", tint: .dsInfo)
            VStack(spacing: 14) {
                Button {
                    navigate(.helpFeedback)
                } label: {
                    SettingRow(icon: "lifepreserver", iconTint: .dsInfo,
                               title: "Help Center & Shortcuts",
                               subtitle: "iOS Action Button & Back Tap setups") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    navigate(.marketingKit)
                } label: {
                    SettingRow(icon: "megaphone.fill", iconTint: .dsAccent,
                               title: "Launch Marketing Kit",
                               subtitle: "Approved campaign copy & assets") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    navigate(.helpFeedback)
                } label: {
                    SettingRow(icon: "heart.fill", iconTint: .dsError,
                               title: "Request Feature / Feedback",
                               subtitle: "Contact DateSnap support") {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .dsGlassCard()
        }
    }
}
