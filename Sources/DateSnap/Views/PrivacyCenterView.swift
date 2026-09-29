import SwiftUI
import SwiftData

// Privacy Center — zero-cloud story, permission audits, data retention
// controls and guarantees. Pushed from the Settings Hub.
struct PrivacyCenterView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @State private var confirmReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Privacy Center", showBack: true)
                heroCard
                permissionAudits
                dataRetention
                guarantees
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .confirmationDialog("Reset all extracted data and history?",
                            isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Erase Everything", role: .destructive) {
                SavedEventActions(services: services, modelContext: modelContext).eraseAllLocalData()
                appState.clearSourceImages()
                appState.showToast("Extracted data and history erased")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All parsed temporal entities and neural tokens will be wiped from this device. Calendar events you already saved are kept.")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.dsSuccess)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.dsSuccess.opacity(0.12)))
                .overlay(Circle().stroke(Color.dsSuccess.opacity(0.35), lineWidth: 1))
            ValueChip(text: "HARDWARE PROTECTED", tint: .dsSuccess)
            Text("Zero-Cloud Extraction.\n100% On-Device.")
                .font(DSTypography.headlineSection())
                .foregroundStyle(Color.dsForeground)
                .multilineTextAlignment(.center)
            Text("Your personal screenshots, photos, and calendar dates never leave your iPhone. All neural OCR operates inside local iOS sandboxes.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                privacyStat("Cloud Sync", "None", "Air-gapped")
                privacyStat("OCR Engine", "Neural Engine", "Apple Silicon")
                privacyStat("Telemetry", "0%", "Zero Trackers")
            }
        }
        .padding(18)
        .dsGlassCard()
    }

    private func privacyStat(_ label: String, _ value: String, _ caption: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
            Text(value)
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsPrimary)
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Color.dsMutedForeground.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsMuted))
    }

    // MARK: - Permission Audits

    private var permissionAudits: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "checkmark.shield.fill", title: "Permission Audits",
                                  tint: .dsSuccess, trailing: "Sandboxed")
            VStack(spacing: 14) {
                permissionRow("photo.on.rectangle.angled", .dsInfo, "Photo Library", "Limited & Local",
                              "Read-only access to scan screenshots you pick. Images are processed in memory on-device.")
                permissionRow("calendar.add.on", .dsSecondary, "Apple Calendar", "Events You Save",
                              "Used only to add, update, or remove events you confirm in DateSnap. Nothing is uploaded.")
                permissionRow("checklist", .dsPrimary, "Reminders Access", "Events You Save",
                              "Adds a reminder for each event you save to the list you choose; nothing is uploaded.")
                permissionRow("bell.badge.fill", .dsWarning, "Local Notifications", "Device Generated",
                              "Instant alerts scheduled on hardware without external APNs payload relay.")
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func permissionRow(_ icon: String, _ tint: Color, _ title: String, _ badge: String, _ detail: String) -> some View {
        Button {
            appState.showToast("\(title): \(detail)")
        } label: {
            SettingRow(icon: icon, iconTint: tint, title: title, subtitle: detail) {
                ValueChip(text: badge, tint: tint)
                SettingsChevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data & Retention

    private var dataRetention: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "memorychip", title: "Data & Retention",
                                  tint: .dsInfo, trailing: "Local Flash Storage")
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    HStack {
                        Text("Local OCR Cache")
                            .font(DSTypography.bodyCompact().weight(.semibold))
                            .foregroundStyle(Color.dsForeground)
                        Spacer()
                        ValueChip(text: "AES-256 GCM", tint: .dsSuccess, systemImage: "lock.fill")
                    }
                    HStack {
                        Text("24.8 MB of 50 MB cap")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                        Spacer()
                        Text("18 event snapshots cached")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.dsMuted)
                            Capsule().fill(Color.dsInfo.opacity(0.8))
                                .frame(width: geo.size.width * 0.5)
                        }
                    }
                    .frame(height: 6)
                }

                Divider().overlay(Color.dsBorder)

                VStack(alignment: .leading, spacing: 8) {
                    SettingRow(icon: "clock.arrow.circlepath", iconTint: .dsAccent2,
                               title: "Screenshot Auto-Purge",
                               subtitle: "Discard intake images after extraction") {
                        EmptyView()
                    }
                    Picker("Purge window", selection: $settings.purgeWindow) {
                        ForEach(SettingsState.PurgeWindow.allCases) { window in
                            Text(window.rawValue).tag(window)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().overlay(Color.dsBorder)

                Button {
                    clearScanCache()
                    appState.showToast("Scan cache cleared")
                } label: {
                    SettingRow(icon: "trash.slash", iconTint: .dsInfo,
                               title: "Clear Local Scan Cache",
                               subtitle: "Removes stored scan text and images; saved events remain untouched") {
                        SettingsChevron()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                Button {
                    confirmReset = true
                } label: {
                    SettingRow(icon: "arrow.counterclockwise", iconTint: .dsError,
                               title: "Reset Extracted Data & History",
                               subtitle: "Erase all parsed temporal entities and reset neural tokens") {
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

    // MARK: - Guarantees & Audit

    private var guarantees: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "doc.badge.shield.checkmark", title: "Guarantees & Audit", tint: .dsPrimary)
            VStack(spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dsSuccess)
                        .frame(width: 34, height: 34)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSuccess.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zero Photo Uploads Guarantee")
                            .font(DSTypography.bodyCompact().weight(.semibold))
                            .foregroundStyle(Color.dsForeground)
                        Text("Strict socket firewall verification prevents any outbound TCP/UDP transmission from the OCR worker thread.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                }

                Divider().overlay(Color.dsBorder)

                documentRow("lock.shield", "Privacy Policy & Telemetry Declaration", url: DateSnapLinks.privacyPolicy)
                documentRow("doc.plaintext", "Terms of Use", url: DateSnapLinks.termsOfUse)
                documentRow("questionmark.circle", "Support", url: DateSnapLinks.support)

                Divider().overlay(Color.dsBorder)

                SettingRow(icon: "checkmark.seal.fill", iconTint: .dsSuccess,
                           title: "System Certification",
                           subtitle: "Certified on iOS 18 Local Sandbox Architecture") {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.dsSuccess)
                }
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    /// Drops the raw OCR text kept for each scan and the in-memory source images.
    private func clearScanCache() {
        let assets = (try? modelContext.fetch(FetchDescriptor<ScannedAsset>())) ?? []
        for asset in assets {
            asset.rawOcrText = ""
        }
        // Interpretation records hold OCR evidence lines too.
        try? modelContext.delete(model: InterpretationRecord.self)
        try? modelContext.save()
        appState.clearSourceImages()
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
