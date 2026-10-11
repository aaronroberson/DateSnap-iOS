import SwiftUI

// MARK: - Automation Settings View (Automatic Capture)
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Automatic-Capture/design.html`.
struct AutomationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(IntelligencePolicy.userDefaultsKey) private var enhancedInterpretation = true
    @AppStorage("settings.automaticCaptureEnabled") private var backgroundRadarEnabled = true
    @AppStorage("settings.discoverySensitivityTier") private var sensitivityTier = 2 // 1 = High, 2 = Balanced, 3 = Broad
    @AppStorage("settings.monitorScreenshots") private var monitorScreenshots = true
    @AppStorage("settings.monitorPhotos") private var monitorPhotos = true
    @AppStorage("settings.lowPowerPause") private var pauseOnLowPower = true

    @State private var capability: IntelligenceCapability = .unavailable(.unknown)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Automatic Capture", showsBack: true) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pdOnPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdPrimary))
                        .accessibilityHidden(true)
                }

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Automatic Capture",
                    subtitle: "Privately scan new camera roll items in the background and suggest verified calendar events for one-tap review."
                )

                // Master Switch Hero Card
                PDCard(highlighted: true) {
                    HStack(spacing: 14) {
                        PDIconTile(systemName: "dot.radiowaves.left.and.right", tint: .pdPrimary, size: .large)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Background Radar")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                PDStatusBadge(text: "LIVE", icon: "bolt.fill", tone: .success)
                            }

                            Text("Privately check newly saved screenshots and photos for date stamps and event posters.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineLimit(2)
                        }

                        Spacer()

                        Toggle("Background Radar", isOn: $backgroundRadarEnabled)
                            .labelsHidden()
                            .toggleStyle(PDToggleStyle())
                    }
                }

                // Highlighted Privacy Vault & Trust Card
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.pdPrimary)
                                Image(systemName: "cpu")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.pdSecondary)
                            }
                            Spacer()
                            PDChip(text: "Zero Cloud Telemetry", icon: "lock.shield.fill", selected: true)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% On-Device Neural Privacy")
                                .font(PDFont.headlineSM)
                                .foregroundStyle(Color.pdOnSurface)
                            Text("Your photos and screenshots never leave your iPhone. Analysis runs strictly in local silicon sandbox memory without network calls.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineSpacing(2)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.pdSecondary)
                            Text("Encrypted inside Secure Enclave storage")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdSecondary)
                        }
                    }
                }

                // Discovery Sensitivity Selector
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Discovery Sensitivity", trailing: "Adaptive OCR")

                    tierCard(
                        tier: 1,
                        title: "High Confidence Only (95%+)",
                        description: "Only flags explicit calendar invitations and confirmed concert ticket stubs."
                    )

                    tierCard(
                        tier: 2,
                        title: "Balanced Discovery",
                        description: "Detects flyers, travel boarding confirmations, SMS date screenshots, and appointment cards.",
                        badge: "RECOMMENDED"
                    )

                    tierCard(
                        tier: 3,
                        title: "Broad Discovery",
                        description: "Surfaces any photo containing dates, weekdays, or time references."
                    )
                }

                // Apple Intelligence Ambient Model Card
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack {
                            PDIconTile(systemName: "wand.and.stars", tint: .pdPrimary)
                            Text("Apple Intelligence Enhancement")
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

                // Monitored Assets & Pace
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Monitored Assets & Pace")

                    PDGroupedList {
                        PDToggleRow(
                            icon: "camera.viewfinder",
                            tint: .pdPrimary,
                            title: "Screenshots & Clips",
                            subtitle: "Instant notification upon taking screenshots",
                            isOn: $monitorScreenshots
                        )
                        PDRowDivider()
                        PDToggleRow(
                            icon: "photo.on.rectangle.angled",
                            tint: .pdSecondary,
                            title: "Camera Roll Photos",
                            subtitle: "Scans flyers and poster photos",
                            isOn: $monitorPhotos
                        )
                        PDRowDivider()
                        PDToggleRow(
                            icon: "battery.100.bolt",
                            tint: .pdWarning,
                            title: "Pause in Low Power Mode",
                            subtitle: "Preserves battery when below 20%",
                            isOn: $pauseOnLowPower
                        )
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

    private func tierCard(tier: Int, title: String, description: String, badge: String? = nil) -> some View {
        let isSelected = sensitivityTier == tier
        return Button {
            sensitivityTier = tier
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdOnSurface)

                        if let badge {
                            PDStatusBadge(text: badge, tone: isSelected ? .success : .neutral)
                        }
                    }

                    Text(description)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineSpacing(2)
                }

                Spacer()

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
