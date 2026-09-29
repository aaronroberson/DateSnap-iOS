import SwiftUI

// Automation Settings — scan modes, capture scope, AI confidence tuning,
// digest alerts and energy throttling. Pushed from the Settings Hub.
struct AutomationSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @AppStorage(IntelligencePolicy.userDefaultsKey) private var enhancedInterpretation = true
    @State private var capability: IntelligenceCapability = .unavailable(.unknown)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Automation Settings", showBack: true)
                engineStatus
                enhancedInterpretationSection
                scanModes
                captureScope
                confidenceTuning
                digestAlerts
                energyThrottling
                sandboxGuarantee
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
        .task { capability = IntelligenceComposition.currentCapability() }
    }

    // MARK: - Enhanced Interpretation (Apple Intelligence)

    private var capabilityText: String {
        if !enhancedInterpretation { return IntelligenceUnavailableReason.disabledByUser.userFacingDescription }
        switch capability {
        case .available:
            return "Available. When a flyer is ambiguous, Apple Intelligence on this iPhone helps read it. Text never leaves your device."
        case .unavailable(let reason):
            return reason.userFacingDescription
        }
    }

    private var enhancedInterpretationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "wand.and.sparkles", title: "Enhanced Interpretation", tint: .dsPrimary,
                                  trailing: capability.isAvailable && enhancedInterpretation ? "On Device" : nil)
            VStack(alignment: .leading, spacing: 10) {
                SettingRow(icon: "text.viewfinder", iconTint: .dsPrimary,
                           title: "Use Apple Intelligence for tricky flyers",
                           subtitle: "Every suggestion is checked against the flyer text; you confirm before anything is saved.") {
                    Toggle("Use Apple Intelligence for tricky flyers", isOn: $enhancedInterpretation)
                        .labelsHidden()
                        .tint(Color.dsPrimary)
                }
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: capability.isAvailable && enhancedInterpretation ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(capability.isAvailable && enhancedInterpretation ? Color.dsSuccess : Color.dsMutedForeground)
                    Text(capabilityText)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .accessibilityElement(children: .combine)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Engine Status

    private var engineStatus: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.dsSuccess)
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.dsSuccess, radius: 4)
                Text("ENGINE STATUS")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsSuccess)
                Spacer()
                Text("Ready & Listening")
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsForeground)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Intelligent Scan Dispatcher")
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
                Text("Autonomous temporal extraction tuned for battery preservation. iOS triggers scans opportunistically when you capture screenshots.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
        .padding(16)
        .dsGlassCard()
    }

    // MARK: - Scan Modes

    private var scanModes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "cpu.fill", title: "Scan Automation Mode",
                                  tint: .dsSecondary, trailing: "3 Profiles")
            VStack(spacing: 10) {
                ForEach(SettingsState.ScanProfile.allCases) { profile in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { settings.scanProfile = profile }
                        appState.showToast("\(profile.rawValue) activated")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: profile.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(settings.scanProfile == profile ? Color.dsPrimary : Color.dsMutedForeground)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(settings.scanProfile == profile ? Color.dsPrimary.opacity(0.14) : Color.dsMuted)
                                )
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(profile.rawValue)
                                        .font(DSTypography.bodyCompact().weight(.semibold))
                                        .foregroundStyle(Color.dsForeground)
                                    ValueChip(text: profile.badge,
                                              tint: profile == .review ? .dsSuccess : (profile == .smartSave ? .dsAccent2 : .dsMutedForeground))
                                }
                                Text(profile.subtitle)
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsSecondary)
                                Text(profile.blurb)
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: settings.scanProfile == profile ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(settings.scanProfile == profile ? Color.dsSuccess : Color.dsMutedForeground.opacity(0.5))
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(settings.scanProfile == profile ? Color.dsPrimary.opacity(0.06) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(settings.scanProfile == profile ? Color.dsPrimary.opacity(0.4) : Color.dsBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .dsGlassCard()
        }
    }

    // MARK: - Capture Scope

    private var captureScope: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "photo.on.rectangle.angled", title: "Capture Scope & Intake", tint: .dsInfo)
            VStack(spacing: 14) {
                Text("Select media repository monitored for schedule patterns:")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    settings.captureScopeCameraPhotos = false
                } label: {
                    SettingRow(icon: "camera.viewfinder", iconTint: .dsInfo,
                               title: "Screenshots Only",
                               subtitle: "Strict privacy filter • Minimal battery footprint") {
                        Image(systemName: !settings.captureScopeCameraPhotos ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(!settings.captureScopeCameraPhotos ? Color.dsSuccess : Color.dsMutedForeground.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    settings.captureScopeCameraPhotos = true
                } label: {
                    SettingRow(icon: "camera.fill", iconTint: .dsSecondary,
                               title: "Screenshots & Camera Photos",
                               subtitle: "Scans event posters and receipts captured via camera") {
                        Image(systemName: settings.captureScopeCameraPhotos ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(settings.captureScopeCameraPhotos ? Color.dsSuccess : Color.dsMutedForeground.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().overlay(Color.dsBorder)

                SettingToggleRow(icon: "arrow.down.circle", iconTint: .dsAccent2,
                                 title: "Include AirDrop & Shared",
                                 subtitle: "Automatically scan media saved from external devices",
                                 isOn: $settings.includeAirDropShared)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Confidence Tuning

    private var confidenceTuning: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "slider.horizontal.3", title: "AI Confidence Tuning", tint: .dsAccent)
            VStack(spacing: 14) {
                HStack {
                    Text("Detection Precision")
                        .font(DSTypography.bodyCompact().weight(.semibold))
                        .foregroundStyle(Color.dsForeground)
                    Spacer()
                    ValueChip(text: "High Precision • \(Int(settings.confidence))%", tint: .dsPrimary)
                }

                VStack(spacing: 6) {
                    Slider(value: $settings.confidence, in: 50...100, step: 5)
                        .tint(Color.dsPrimary)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("50%").font(DSTypography.overlineConfidence()).foregroundStyle(Color.dsMutedForeground)
                            Text("Catch All").font(.system(size: 10)).foregroundStyle(Color.dsMutedForeground.opacity(0.7))
                        }
                        Spacer()
                        VStack {
                            Text("70%").font(DSTypography.overlineConfidence()).foregroundStyle(Color.dsMutedForeground)
                            Text("Balanced").font(.system(size: 10)).foregroundStyle(Color.dsMutedForeground.opacity(0.7))
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("85%+").font(DSTypography.overlineConfidence()).foregroundStyle(Color.dsPrimary)
                            Text("Precision").font(.system(size: 10)).foregroundStyle(Color.dsPrimary.opacity(0.8))
                        }
                    }
                }

                Text("Recommended 85% prevents false alarms from memes, receipts, or chat conversations.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)

                Divider().overlay(Color.dsBorder)

                SettingToggleRow(icon: "pencil.line", iconTint: .dsWarning,
                                 title: "Draft Low Confidence Events",
                                 subtitle: "Never lose a date even if concert flyer typography is messy",
                                 isOn: $settings.draftLowConfidence)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Digest & Alerts

    private var digestAlerts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "bell.badge.fill", title: "Digest & Notification Alerts", tint: .dsPrimary)
            VStack(spacing: 14) {
                SettingToggleRow(icon: "bolt.badge.clock", iconTint: .dsPrimary,
                                 title: "Quick Extraction Prompt",
                                 subtitle: "System banner prompt right after capturing an event flyer",
                                 isOn: $settings.quickExtractionPrompt)
                Divider().overlay(Color.dsBorder)
                SettingToggleRow(icon: "moon.stars.fill", iconTint: .dsSecondary,
                                 title: "Evening Discovery Digest",
                                 subtitle: "9:00 PM summary card grouping today's pending schedule cards",
                                 isOn: $settings.eveningDigest)
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    // MARK: - Energy

    private var energyThrottling: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "battery.75", title: "Hardware & Energy Throttling", tint: .dsSuccess)
            VStack(spacing: 14) {
                SettingToggleRow(icon: "bolt.slash", iconTint: .dsWarning,
                                 title: "Pause on Low Power Mode",
                                 subtitle: "Suspends all automated background neural passes when battery drops",
                                 isOn: $settings.pauseOnLowPower)
                Divider().overlay(Color.dsBorder)
                VStack(alignment: .leading, spacing: 6) {
                    SettingRow(icon: "clock.arrow.circlepath", iconTint: .dsInfo,
                               title: "Adaptive iOS Task Cadence") {
                        EmptyView()
                    }
                    Text("Apple Neural Engine scheduling operates in discrete burst cycles. Scans execute opportunistically during phone charging or active gallery edits.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private var sandboxGuarantee: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.dsSuccess)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsSuccess.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text("iOS Sandbox Respect Guarantee")
                    .font(DSTypography.bodyCompact().weight(.semibold))
                    .foregroundStyle(Color.dsForeground)
                Text("Background scans run strictly when system capacity permits. DateSnap will never employ continuous background audio tricks, artificial GPS wake locks, or unprompted battery drains. Your snapshots stay encrypted on-device.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
        .padding(16)
        .dsGlassCard(borderColor: Color.dsSuccess.opacity(0.25))
    }
}
