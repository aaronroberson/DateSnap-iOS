import SwiftUI

// MARK: - Reminder Settings View (Presets & Preview)
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Reminder-Presets/design.html`.
struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var previewEventStart: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedPresetId: String = "standard"

    struct PresetBundle: Identifiable {
        let id: String
        let title: String
        let timing: String
        let description: String
        let offsets: [ReminderOffset]
        let tint: Color
    }

    private let presets: [PresetBundle] = [
        PresetBundle(
            id: "standard",
            title: "Standard Smart",
            timing: "24h before + 2h before",
            description: "Balanced safety net for everyday appointments and social events.",
            offsets: ReminderOffset.defaultStaggered,
            tint: .pdPrimary
        ),
        PresetBundle(
            id: "travel",
            title: "Travel Ready",
            timing: "48h + 24h + 3h airport buffer",
            description: "Built for boarding passes, hotel check-ins, and flight departures.",
            offsets: [
                .twoDaysBefore,
                .oneDayBefore,
                .threeHoursBefore
            ],
            tint: .pdSecondary
        ),
        PresetBundle(
            id: "minimal",
            title: "Minimal Focus",
            timing: "1h before only",
            description: "Clean calendar with single departure ping right before starting.",
            offsets: [
                .oneHourBefore
            ],
            tint: .pdTertiary
        ),
        PresetBundle(
            id: "neverMiss",
            title: "Never Miss It",
            timing: "1 week + 2 days + 4 hours",
            description: "Multi-tier alerts for high-stakes exams, weddings, and ticket drops.",
            offsets: [
                .oneWeekBefore,
                .twoDaysBefore,
                ReminderOffset(timeInterval: -14400, label: "4 hours before")
            ],
            tint: .pdPrimary
        )
    ]

    private var activeOffsets: [ReminderOffset] {
        presets.first(where: { $0.id == selectedPresetId })?.offsets ?? ReminderOffset.defaultStaggered
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Reminder Presets", showsBack: true) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.pdOnPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdPrimary))
                        .accessibilityHidden(true)
                }

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Reminder Presets",
                    subtitle: "Configure default notification offset templates automatically applied when events are extracted."
                )

                // Automated Contextual Timing Hero Card
                PDCard {
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        HStack(spacing: PDSpacing.sm) {
                            PDIconTile(systemName: "bell.badge.fill", tint: .pdPrimary, size: .large)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Automated Contextual Timing")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                PDStatusBadge(text: "Smart Presets", icon: "sparkles", tone: .info)
                            }
                        }

                        Text("Pencil’d suggests alert timing for each event based on its type. You can adjust the alerts on any event before saving.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .lineSpacing(2)
                    }
                }

                // Quick Preset Bundles Section
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Quick Preset Bundles", trailing: "Tap to apply pattern")

                    ForEach(presets) { preset in
                        let isSelected = preset.id == selectedPresetId
                        Button {
                            selectedPresetId = preset.id
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.title)
                                            .font(PDFont.labelLG)
                                            .foregroundStyle(Color.pdOnSurface)
                                        Text(preset.timing)
                                            .font(PDFont.bodySM)
                                            .foregroundStyle(preset.tint)
                                    }
                                    Spacer()
                                    if isSelected {
                                        ZStack {
                                            Circle()
                                                .fill(Color.pdPrimaryContainer)
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color.pdOnPrimary)
                                        }
                                    }
                                }

                                Text(preset.description)
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .lineLimit(2)
                            }
                            .padding(PDSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: PDRadius.card)
                                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdSelected) : AnyShapeStyle(Color.pdSurfaceLow.opacity(0.9)))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: PDRadius.card)
                                    .stroke(isSelected ? Color.pdPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Interactive Event Timing Preview Section
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    PDSectionHeader(title: "Live Timing Preview")

                    PDCard {
                        VStack(alignment: .leading, spacing: PDSpacing.md) {
                            DatePicker(
                                "Simulated Event",
                                selection: $previewEventStart,
                                in: Date.now...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .font(PDFont.bodyMD)
                            .tint(Color.pdPrimary)

                            Rectangle()
                                .fill(Color.pdSurfaceHighest.opacity(0.6))
                                .frame(height: 1)

                            ForEach(activeOffsets) { offset in
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.pdPrimary)
                                        .frame(width: 24)

                                    Text(offset.label.capitalized)
                                        .font(PDFont.bodyMD.weight(.semibold))
                                        .foregroundStyle(Color.pdOnSurface)

                                    Spacer()

                                    Text(offset.triggerDate(forEventStart: previewEventStart, isAllDay: false)
                                        .formatted(date: .abbreviated, time: .shortened))
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
    }
}
