import SwiftUI

// MARK: - Reminder Settings View (Default Reminders)
/// Mirrors Stitch design `.stitch/Settings-Functional-Sub-Screens/Settings/Reminder-Presets/design.html`.
/// Picks the preset every new event starts with (`ReminderDefaultsStore`). The presets are the same
/// ones the per-event Reminder Schedule editor offers; each event can still be changed before saving.
struct ReminderSettingsView: View {
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState
    @State private var previewEventStart: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var selectedPreset: ReminderPreset = .defaultPreset

    private let store = ReminderDefaultsStore()

    private var maxAlerts: Int { PlanLimits.maxAlertsPerEvent(services.subscription.entitlementSnapshot) }

    /// The alerts a new event gets on this plan: the preset, trimmed to the plan's alert limit.
    private var activeOffsets: [ReminderOffset] {
        selectedPreset.offsets(limitedTo: maxAlerts) ?? Array(ReminderOffset.defaultStaggered.prefix(maxAlerts))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: PDSpacing.lg) {
                PDTopBar(title: "Default Reminders", showsBack: true)

                PDScreenIntro(
                    eyebrow: "Settings",
                    title: "Default Reminders",
                    subtitle: "Choose the alerts every new event starts with. You can change them on any event before saving."
                )

                presetList

                if PlanLimits.canUpgradeAlerts(from: maxAlerts) {
                    PDCard {
                        HStack(alignment: .top, spacing: PDSpacing.sm) {
                            PDIconTile(systemName: "bell.badge.fill", tint: .pdSecondary)
                            Text(PlanLimits.alertLimitMessage)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                timingPreview
            }
            .padding(.horizontal, PDSpacing.margin)
            .padding(.top, PDSpacing.sm)
            .padding(.bottom, PDSpacing.xl)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .onAppear { selectedPreset = store.preset() }
    }

    // MARK: - Presets
    private var presetList: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Presets")

            ForEach(ReminderPreset.defaultChoices) { preset in
                let isSelected = preset == selectedPreset
                let offsets = preset.offsets ?? []
                Button {
                    choose(preset)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        PDIconTile(systemName: preset.icon, tint: .pdPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(preset.settingsTitle)
                                    .font(PDFont.labelLG)
                                    .foregroundStyle(Color.pdOnSurface)
                                if isLocked(preset) {
                                    PDStatusBadge(text: "Plus", icon: "lock.fill", tone: .info)
                                }
                            }
                            Text(offsets.map(\.label).joined(separator: " · "))
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdPrimary)
                            Text(preset.settingsDetail)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.pdPrimary)
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(PDSpacing.md)
                    .frame(minHeight: 44)
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
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func isLocked(_ preset: ReminderPreset) -> Bool {
        preset.isLocked(maxAlerts: maxAlerts)
    }

    private func choose(_ preset: ReminderPreset) {
        guard !isLocked(preset) else {
            Task { await appState.present(.paywall(opening: .plus)) }
            return
        }
        selectedPreset = preset
        store.setPreset(preset)
    }

    // MARK: - Preview
    private var timingPreview: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Preview")

            PDCard {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    DatePicker(
                        "Example event",
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
}
