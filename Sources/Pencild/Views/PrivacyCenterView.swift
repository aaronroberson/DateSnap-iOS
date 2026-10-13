import SwiftUI
import SwiftData

// MARK: - Privacy & Processing View
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Privacy-And-Processing/design.html`.
struct PrivacyCenterView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    @State private var confirmReset = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Privacy & Processing", showsBack: true)

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Privacy & Processing",
                    subtitle: "How Pencil’d handles your screenshots and flyers, and how to clear what it stores."
                )

                // 100% On-Device Neural Engine Hero Card
                PDCard(highlighted: true) {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack {
                            PDIconTile(systemName: "shield.lefthalf.filled.badge.checkmark", tint: .pdPrimary, size: .large)

                            Spacer()

                            PDStatusBadge(text: "On device", icon: "checkmark.shield.fill", tone: .success)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Analyzed on your device")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                            Text("Pencil’d reads your screenshots, photos and PDFs on your iPhone. Images and extracted text are not sent to Pencil’d servers, and there is no Pencil’d account to sign in to.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineSpacing(2)
                        }

                        HStack(spacing: PDSpacing.sm) {
                            PDChip(text: "On-device analysis", icon: "cpu", selected: true)
                        }
                    }
                }

                // Storage Actions
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Data on this device")

                    PDGroupedList {
                        Button {
                            let result = SavedEventActions(services: services, modelContext: modelContext).clearScanCache()
                            report(result, success: "Scan cache cleared") {
                                appState.clearSourceImages()
                            }
                        } label: {
                            PDListRow(
                                icon: "trash.circle.fill",
                                tint: .pdPrimary,
                                title: "Clear scanned text",
                                subtitle: "Removes stored OCR text and interpretation details from past scans. Saved events stay."
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
