import SwiftUI

struct AutomationSettingsView: View {
    @AppStorage(IntelligencePolicy.userDefaultsKey) private var enhancedInterpretation = true
    @State private var capability: IntelligenceCapability = .unavailable(.unknown)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Enhanced Interpretation", showBack: true)

                VStack(alignment: .leading, spacing: 10) {
                    SettingsSectionHeader(
                        icon: "wand.and.sparkles",
                        title: "Apple Intelligence",
                        tint: .dsPrimary,
                        trailing: capability.isAvailable ? "On Device" : nil
                    )
                    VStack(alignment: .leading, spacing: 12) {
                        SettingRow(
                            icon: "text.viewfinder",
                            iconTint: .dsPrimary,
                            title: "Use Apple Intelligence for ambiguous flyers",
                            subtitle: "Suggestions are checked against the flyer text. You review the event before saving."
                        ) {
                            Toggle(
                                "Use Apple Intelligence for ambiguous flyers",
                                isOn: $enhancedInterpretation
                            )
                            .labelsHidden()
                            .tint(Color.dsPrimary)
                            .disabled(!capability.isAvailable)
                            .accessibilityLabel("Use Apple Intelligence for ambiguous flyers")
                        }

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: capability.isAvailable && enhancedInterpretation
                                  ? "checkmark.circle.fill" : "info.circle")
                                .foregroundStyle(capability.isAvailable && enhancedInterpretation
                                                 ? Color.dsSuccess : Color.dsMutedForeground)
                            Text(statusDescription)
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .padding(16)
                    .dsGlassCard()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Rules-based extraction remains available", systemImage: "text.magnifyingglass")
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Text("When Apple Intelligence is turned off or unavailable, DateSnap continues with deterministic text extraction and asks you to review any event it finds.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .dsGlassCard()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .task { capability = IntelligenceComposition.currentCapability() }
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
