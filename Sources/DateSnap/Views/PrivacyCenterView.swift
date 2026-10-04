import SwiftUI
import SwiftData

struct PrivacyCenterView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @State private var confirmReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Privacy Center", showBack: true)
                privacySummary
                dataActions
                privacyResources
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .confirmationDialog(
            "Reset DateSnap data and history?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Erase Everything", role: .destructive) {
                let result = SavedEventActions(services: services, modelContext: modelContext).eraseAllLocalData()
                report(result, success: "DateSnap data and history erased") {
                    appState.clearSourceImages()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases locally stored scans and event history. Calendar and Reminders items already saved to Apple apps are kept.")
        }
    }

    private var privacySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock.iphone")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.dsPrimary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.dsPrimary.opacity(0.12)))
            Text("Your scans stay in DateSnap until you choose an action.")
                .font(DSTypography.headlineSection())
                .foregroundStyle(Color.dsForeground)
            Text("Apple Vision recognizes text on this device. DateSnap stores scan text locally; saving an event can also write to the Apple Calendar or Reminders list you select.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .dsGlassCard()
    }

    private var dataActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "internaldrive", title: "Local Data", tint: .dsInfo)
            VStack(spacing: 12) {
                Text("Clear scan text and interpretation records while keeping event history. Reset removes DateSnap scans and event history.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    let result = SavedEventActions(services: services, modelContext: modelContext).clearScanCache()
                    report(result, success: "Scan text and interpretation records cleared") {
                        appState.clearSourceImages()
                    }
                } label: {
                    SettingRow(
                        icon: "trash.slash",
                        iconTint: .dsInfo,
                        title: "Clear Scan Text",
                        subtitle: "Saved events remain"
                    ) {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    confirmReset = true
                } label: {
                    SettingRow(
                        icon: "arrow.counterclockwise",
                        iconTint: .dsError,
                        title: "Reset DateSnap Data & History",
                        subtitle: "Calendar and Reminders items remain in Apple apps"
                    ) {
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

    private var privacyResources: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "doc.badge.shield.checkmark", title: "Privacy Resources", tint: .dsPrimary)
            VStack(spacing: 14) {
                documentRow("lock.shield", "Privacy Policy", url: DateSnapLinks.privacyPolicy)
                Divider().overlay(Color.dsBorder)
                documentRow("doc.plaintext", "Terms of Use", url: DateSnapLinks.termsOfUse)
                Divider().overlay(Color.dsBorder)
                documentRow("questionmark.circle", "Support", url: DateSnapLinks.support)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func report(_ result: MutationResult, success: String, onCompleted: () -> Void) {
        switch result {
        case .success:
            onCompleted()
            appState.showToast(success)
        case .partial(let issues):
            onCompleted()
            appState.showToast("\(success). \(issues.joined(separator: "; "))")
        case .failure(let error):
            appState.showToast("Could not complete the request: \(error.localizedDescription)")
        }
    }

    private func documentRow(_ icon: String, _ title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            SettingRow(icon: icon, iconTint: .dsSecondary, title: title) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
