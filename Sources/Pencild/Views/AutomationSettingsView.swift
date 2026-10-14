import SwiftUI

// MARK: - Auto-detect Settings (Automatic Capture)
/// Stitch reference: `.stitch/Settings-Functional-Sub-Screens/Settings/Automatic-Capture/design.html`.
///
/// Pencil’d does not scan in the background. iOS does not let an app read the photo library while
/// it is closed, so auto-detect runs only while Pencil’d is open: it looks at the newest
/// screenshots, ranks the likely events, and waits for the user to review. Every control here
/// has a runtime consumer (`AutoDetectPreference`, `IntelligencePolicy`).
struct AutomationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage(IntelligencePolicy.userDefaultsKey) private var enhancedInterpretation = true
    @AppStorage(AutoDetectPreference.key) private var autoDetectEnabled = true

    @State private var capability: IntelligenceCapability = .unavailable(.unknown)

    private var includedInPlan: Bool { appState.isEntitled(to: .automaticScreenshotDetection) }

    /// Free users see the switch off; turning it on opens the Plus paywall instead.
    private var autoDetectBinding: Binding<Bool> {
        Binding(
            get: { includedInPlan && autoDetectEnabled },
            set: { isOn in
                guard includedInPlan else {
                    if isOn { Task { await appState.present(.plusPaywall) } }
                    return
                }
                autoDetectEnabled = isOn
            }
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Auto-detect", showsBack: true)

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Auto-detect screenshots",
                    subtitle: "When you open Pencil’d, it checks your newest screenshots for event dates and lines up likely events for your review."
                )

                // Master switch
                PDCard(highlighted: true) {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack(spacing: 14) {
                            PDIconTile(systemName: "sparkle.magnifyingglass", tint: .pdPrimary, size: .large)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Check new screenshots")
                                        .font(PDFont.headlineSM)
                                        .foregroundStyle(Color.pdOnSurface)
                                    if !includedInPlan {
                                        PDStatusBadge(text: "Plus", icon: "lock.fill", tone: .neutral)
                                    }
                                }
                                Text("Runs while Pencil’d is open. Nothing is saved until you review it.")
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }

                            Spacer()

                            Toggle("Check new screenshots", isOn: autoDetectBinding)
                                .labelsHidden()
                                .toggleStyle(PDToggleStyle())
                        }

                        if !includedInPlan {
                            Text("Auto-detect is included with Plus. You can still scan any screenshot yourself.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                }

                // How it works
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack(spacing: 8) {
                            PDIconTile(systemName: "iphone", tint: .pdSecondary)
                            Text("How it works")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                        }
                        howRow("Looks only at your Screenshots album, newest first.")
                        howRow("Needs Photos access. Limited access works too.")
                        howRow("Does not run when Pencil’d is closed.")
                        howRow("Analysis happens on your iPhone; screenshots are not uploaded.")
                    }
                }

                // Apple Intelligence
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack {
                            PDIconTile(systemName: "wand.and.stars", tint: .pdPrimary)
                            Text("Apple Intelligence")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                            Spacer()
                            if capability.isAvailable {
                                PDStatusBadge(text: "On Device", icon: "checkmark", tone: .success)
                            }
                        }

                        Toggle("Use Apple Intelligence for ambiguous flyers", isOn: $enhancedInterpretation)
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurface)
                            .toggleStyle(PDToggleStyle())
                            .disabled(!capability.isAvailable)

                        Text(statusDescription)
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .task { capability = IntelligenceComposition.currentCapability() }
    }

    private func howRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.pdSuccess)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }

    private var statusDescription: String {
        guard enhancedInterpretation else {
            return IntelligenceUnavailableReason.disabledByUser.userFacingDescription
        }
        switch capability {
        case .available:
            return "Available on this device. Only ambiguous flyers are sent to the on-device model."
        case .unavailable(let reason):
            return reason.userFacingDescription
        }
    }
}

// MARK: - Auto-detect preference
/// The one switch behind "Auto-detect screenshots". Plus entitlement is checked separately by
/// `FeatureAccessPolicy`; this is the user's own on/off choice (default on).
enum AutoDetectPreference {
    static let key = "settings.automaticCaptureEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }
}
