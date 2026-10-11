import SwiftUI
import SwiftData

// MARK: - Privacy & Processing View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Privacy-And-Processing/design.html`.
struct PrivacyCenterView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @AppStorage("settings.strictLocalIsolation") private var strictLocalIsolation = true
    @AppStorage("settings.autoPurgeImages") private var autoPurgeImages = true
    @AppStorage("settings.retainScannedNotes") private var retainScannedNotes = true
    @AppStorage("settings.crashTelemetryOptIn") private var crashTelemetryOptIn = false

    @State private var confirmReset = false
    @State private var cacheCleared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Privacy & Processing", showsBack: true) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pdOnPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdPrimary))
                        .accessibilityHidden(true)
                }

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Privacy & Processing",
                    subtitle: "Inspect on-device neural processing isolation, local image security, and data telemetry policies."
                )

                // 100% On-Device Neural Engine Hero Card
                PDCard(highlighted: true) {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack {
                            PDIconTile(systemName: "shield.lefthalf.filled.badge.checkmark", tint: .pdPrimary, size: .large)

                            Spacer()

                            PDStatusBadge(text: "Apple Silicon Sandbox • Active", icon: "checkmark.shield.fill", tone: .success)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% On-Device Neural Engine")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                            Text("Your calendar captures, screenshots, and PDFs are processed strictly within local device memory. No images or extracted text are ever transmitted to external servers.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineSpacing(2)
                        }

                        HStack(spacing: PDSpacing.sm) {
                            PDChip(text: "Zero Cloud Logging", icon: "cloud.slash.fill", selected: true)
                            PDChip(text: "On-Device Analysis", icon: "cpu", selected: false)
                        }
                    }
                }

                // Processing Architecture Mode
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Processing Architecture Mode")

                    // Strict Local Isolation (Recommended)
                    architectureOptionCard(
                        title: "Strict Local Isolation",
                        description: "OCR and date parsing run entirely on Apple Neural Engine. Zero outbound network calls permitted under any workflow.",
                        badge: "RECOMMENDED",
                        isSelected: strictLocalIsolation
                    ) {
                        strictLocalIsolation = true
                    }

                    // Enhanced Hybrid Parsing
                    architectureOptionCard(
                        title: "Enhanced Hybrid Parsing",
                        description: "Optionally send anonymized unparseable layout geometries for high-accuracy cloud fallback (Disabled by default).",
                        badge: "OFFLINE SAFE",
                        isSelected: !strictLocalIsolation
                    ) {
                        strictLocalIsolation = false
                    }
                }

                // Local Cache & Data Lifecycle
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Local Cache & Data Lifecycle")

                    PDGroupedList {
                        toggleLifecycleRow(
                            icon: "photo.badge.checkmark",
                            title: "Auto-Purge Processed Images",
                            subtitle: "Immediately delete cached temporary image bitmaps after schedule confirmation.",
                            isOn: $autoPurgeImages
                        )
                        PDRowDivider()
                        toggleLifecycleRow(
                            icon: "note.text",
                            title: "Retain Scanned Notes in Calendar",
                            subtitle: "Embed snippet preview in Apple Calendar event notes.",
                            isOn: $retainScannedNotes
                        )
                        PDRowDivider()
                        toggleLifecycleRow(
                            icon: "ant.fill",
                            title: "Crash Telemetry & Diagnostics",
                            subtitle: "Share anonymous runtime exception traces with developers.",
                            badge: "OPT-IN ONLY",
                            isOn: $crashTelemetryOptIn
                        )
                    }
                }

                // Storage Actions
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Storage Actions")

                    PDGroupedList {
                        Button {
                            let result = SavedEventActions(services: services, modelContext: modelContext).clearScanCache()
                            report(result, success: "Scan cache cleared") {
                                appState.clearSourceImages()
                                cacheCleared = true
                            }
                        } label: {
                            PDListRow(
                                icon: "trash.circle.fill",
                                tint: .pdPrimary,
                                title: "Clear In-Memory Vision Cache",
                                subtitle: cacheCleared ? "0.0 MB currently allocated" : "18.4 MB currently allocated"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.pdOutline)
                            }
                        }
                        .buttonStyle(PDRowButtonStyle())

                        PDRowDivider()

                        Button {
                            confirmReset = true
                        } label: {
                            PDListRow(
                                icon: "arrow.counterclockwise.circle.fill",
                                tint: .pdError,
                                title: "Reset Pencil'd Data & History",
                                subtitle: "Calendar and Reminders items remain in Apple apps"
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.pdOutline)
                            }
                        }
                        .buttonStyle(PDRowButtonStyle())
                    }
                }

                // Legal & Policy Links
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Legal & Policies")

                    PDGroupedList {
                        legalLinkRow(icon: "shield.fill", title: "Privacy Policy", url: PencildLinks.privacyPolicy)
                        PDRowDivider()
                        legalLinkRow(icon: "doc.text.fill", title: "Terms of Service", url: PencildLinks.termsOfUse)
                        PDRowDivider()
                        legalLinkRow(icon: "questionmark.circle.fill", title: "Support", url: PencildLinks.support)
                    }
                }
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .confirmationDialog(
            "Reset Pencil'd data and history?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Erase Everything", role: .destructive) {
                let result = SavedEventActions(services: services, modelContext: modelContext).eraseAllLocalData()
                report(result, success: "Pencil'd data and history erased") {
                    appState.clearSourceImages()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases locally stored scans and event history. Calendar and Reminders items already saved to Apple apps are kept.")
        }
    }

    private func architectureOptionCard(title: String, description: String, badge: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.pdPrimary : Color.pdSurfaceHighest)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.pdOnPrimary)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdOnSurface)
                        Spacer()
                        PDStatusBadge(text: badge, tone: isSelected ? .success : .neutral)
                    }
                    Text(description)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineSpacing(2)
                }
            }
            .padding(PDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdSelected) : AnyShapeStyle(Color.pdSurfaceLow.opacity(0.9)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .stroke(isSelected ? Color.pdPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PDRowButtonStyle())
    }

    private func toggleLifecycleRow(icon: String, title: String, subtitle: String, badge: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            PDIconTile(systemName: icon, tint: .pdPrimary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)

                    if let badge {
                        PDStatusBadge(text: badge, tone: .info)
                    }
                }

                Text(subtitle)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            Spacer()

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(PDToggleStyle())
        }
        .padding(PDSpacing.md)
        .frame(minHeight: 56)
    }

    private func legalLinkRow(icon: String, title: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            PDListRow(
                icon: icon,
                tint: .pdOnSurfaceVariant,
                title: title
            ) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.pdOutline)
            }
        }
        .buttonStyle(PDRowButtonStyle())
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
}
