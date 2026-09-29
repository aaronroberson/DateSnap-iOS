import SwiftUI

// Default Reminder Settings — alert presets, editable timed alerts,
// all-day defaults, delivery routing and a live simulation preview.
struct ReminderSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: SettingsState
    @State private var editingAlertID: UUID? = nil

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                SettingsScreenHeader(title: "Default Reminders", showBack: true)
                architectureIntro
                timedEvents
                allDayEvents
                deliveryRouting
                soundHaptics
                simulation
                saveControls
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .dsScreenBackground()
    }

    // MARK: - Intro

    private var architectureIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "tune")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.dsPrimary)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.dsPrimary.opacity(0.14)))
                Text("ALERT ARCHITECTURE")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsPrimary)
            }
            Text("Set your baseline alert schedules. These default presets are automatically pre-populated whenever a new event is extracted.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dsGlassCard()
    }

    // MARK: - Timed Events

    private var timedEvents: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "clock.fill", title: "Timed Events",
                                  tint: .dsSecondary, trailing: "Specific start time")
            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(SettingsState.TimedPreset.allCases) { preset in
                        timedPresetButton(preset)
                    }
                }

                ForEach(settings.timedAlerts) { alert in
                    timedAlertRow(alert)
                }

                Button {
                    if settings.timedAlerts.count >= 3 {
                        appState.showToast("Maximum of 3 default alerts")
                    } else {
                        settings.timedPreset = .thorough
                        settings.timedAlerts.append(
                            SettingsState.TimedAlert(glyph: "bell.fill", title: "1 Hour Before",
                                                     time: Calendar.current.date(from: DateComponents(hour: 19)) ?? Date(),
                                                     channel: "Calendar Notification"))
                        appState.showToast("Default alert added")
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Default Alert")
                    }
                    .font(DSTypography.labelChip())
                    .foregroundStyle(Color.dsPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.dsPrimary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    Text("\(settings.timedAlerts.count) of 3 max")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.dsMutedForeground.opacity(0.7))
                        .offset(x: -14)
                }
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func timedAlertRow(_ alert: SettingsState.TimedAlert) -> some View {
        let isEditing = editingAlertID == alert.id
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: alert.glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dsWarning)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dsWarning.opacity(0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(alert.title) · \(alert.time.formatted(date: .omitted, time: .shortened))")
                        .font(DSTypography.bodyCompact().weight(.semibold))
                        .foregroundStyle(Color.dsForeground)
                    Text(alert.channel)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        editingAlertID = isEditing ? nil : alert.id
                    }
                } label: {
                    Text("Edit")
                        .font(DSTypography.labelChip())
                        .foregroundStyle(Color.dsPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.dsPrimary.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.dsPrimary.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if isEditing {
                VStack(spacing: 10) {
                    DatePicker("Alert time",
                               selection: binding(for: alert),
                               displayedComponents: .hourAndMinute)
                        .font(DSTypography.caption())
                        .tint(Color.dsPrimary)
                    HStack {
                        Text("Channel")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                        Spacer()
                        Menu {
                            ForEach(["Apple Reminders", "Calendar Notification", "DateSnap Local Push"], id: \.self) { channel in
                                Button(channel) { update(alert) { $0.channel = channel } }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(alert.channel)
                                    .font(DSTypography.labelChip())
                                    .foregroundStyle(Color.dsForeground)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.dsMuted))
            }
        }
    }

    private func binding(for alert: SettingsState.TimedAlert) -> Binding<Date> {
        Binding<Date>(
            get: { alert.time },
            set: { newValue in update(alert) { $0.time = newValue } }
        )
    }

    private func update(_ alert: SettingsState.TimedAlert, _ mutate: @escaping (inout SettingsState.TimedAlert) -> Void) {
        if let idx = settings.timedAlerts.firstIndex(where: { $0.id == alert.id }) {
            mutate(&settings.timedAlerts[idx])
        }
    }

    @ViewBuilder
    private func timedPresetButton(_ preset: SettingsState.TimedPreset) -> some View {
        let isSelected = settings.timedPreset == preset
        Button {
            withAnimation(.easeOut(duration: 0.2)) { settings.applyTimedPreset(preset) }
        } label: {
            VStack(spacing: 2) {
                Text(preset.rawValue)
                    .font(DSTypography.labelChip())
                    .foregroundStyle(isSelected ? Color.dsPrimaryForeground : Color.dsForeground)
                Text(preset.caption)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.dsPrimaryForeground.opacity(0.8) : Color.dsMutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(Color.dsPrimaryAction) : AnyShapeStyle(Color.dsMuted))
            )
            .overlay(Capsule().stroke(isSelected ? Color.dsPrimary.opacity(0.5) : Color.dsBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - All-Day Events

    private var allDayEvents: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "calendar", title: "All-Day Events",
                                  tint: .dsInfo, trailing: "9:00 AM standard")
            VStack(spacing: 14) {
                Text("All-day events trigger at 9:00 AM local time on your designated day offsets.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    allDayCard("Alert 1", "Day of Event", "9:00 AM Morning", $settings.allDayDayOf)
                    allDayCard("Alert 2", "1 Day Before", "9:00 AM Briefing", $settings.allDayDayBefore)
                }
            }
            .padding(16)
            .dsGlassCard()
        }
    }

    private func allDayCard(_ tag: String, _ title: String, _ caption: String, _ isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(tag.uppercased())
                        .font(DSTypography.overlineConfidence())
                        .foregroundStyle(Color.dsMutedForeground)
                    Spacer()
                    Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(isOn.wrappedValue ? Color.dsSuccess : Color.dsMutedForeground.opacity(0.5))
                }
                Text(title)
                    .font(DSTypography.bodyCompact().weight(.semibold))
                    .foregroundStyle(Color.dsForeground)
                Text(caption)
                    .font(DSTypography.caption())
                    .foregroundStyle(isOn.wrappedValue ? Color.dsPrimary : Color.dsMutedForeground)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isOn.wrappedValue ? Color.dsPrimary.opacity(0.06) : Color.dsMuted.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isOn.wrappedValue ? Color.dsPrimary.opacity(0.4) : Color.dsBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delivery Routing

    private var deliveryRouting: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "point.3.connected.trianglepath.dotted", title: "Delivery Routing",
                                  tint: .dsAccent, trailing: "Auto-Routing")
            HStack(spacing: 10) {
                ForEach(SettingsState.DeliveryRoute.allCases) { route in
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { settings.routePrimary = route }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: route.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(settings.routePrimary == route ? Color.dsPrimary : Color.dsMutedForeground)
                            Text(route.rawValue)
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsForeground)
                            Text(route.subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(settings.routePrimary == route ? Color.dsPrimary : Color.dsMutedForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(settings.routePrimary == route ? Color.dsPrimary.opacity(0.08) : Color.dsMuted.opacity(0.5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(settings.routePrimary == route ? Color.dsPrimary.opacity(0.5) : Color.dsBorder, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Sound & Haptics

    private var soundHaptics: some View {
        HStack {
            SettingRow(icon: "speaker.wave.2.fill", iconTint: .dsAccent,
                       title: "Sound & Haptics",
                       subtitle: settings.alertSound) {
                Menu {
                    ForEach(["Crystal Chime (Haptic Pulse)", "Gentle Bell", "Haptics Only", "Silent"], id: \.self) { sound in
                        Button(sound) {
                            settings.alertSound = sound
                            appState.showToast("Alert sound set to \(sound)")
                        }
                    }
                } label: {
                    Text("Change")
                        .font(DSTypography.labelChip())
                        .foregroundStyle(Color.dsPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.dsPrimary.opacity(0.12)))
                        .overlay(Capsule().stroke(Color.dsPrimary.opacity(0.35), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .dsGlassCard()
    }

    // MARK: - Active Simulation

    private var simulation: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeader(icon: "waveform.path.ecg", title: "Active Simulation",
                                  tint: .dsWarning, trailing: "Dynamic Preview")
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    DSDateBadge(month: "OCT", day: "24", isSelected: true)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Neon Horizon Tour")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            ValueChip(text: "98% Match", tint: .dsSuccess)
                        }
                        Text("Fri · 8:00 PM - 11:30 PM")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    Spacer()
                }

                Divider().overlay(Color.dsBorder)

                ForEach(Array(settings.timedAlerts.enumerated()), id: \.element.id) { index, alert in
                    HStack(spacing: 10) {
                        Image(systemName: alert.glyph)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.dsPrimary)
                            .frame(width: 22)
                        Text("Alert \(index + 1)")
                            .font(DSTypography.caption().weight(.semibold))
                            .foregroundStyle(Color.dsMutedForeground)
                        Spacer()
                        Text("\(offsetTitle(for: alert)) · \(alert.time.formatted(date: .omitted, time: .shortened))")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsForeground)
                    }
                    if index < settings.timedAlerts.count - 1 {
                        Divider().overlay(Color.dsBorder.opacity(0.5))
                    }
                }
            }
            .padding(16)
            .dsGlassCard(borderColor: Color.dsWarning.opacity(0.3))
        }
    }

    private func offsetTitle(for alert: SettingsState.TimedAlert) -> String {
        switch alert.title {
        case "1 Day Before": return "Thu, Oct 23"
        case "2 Hours Before": return "Fri, Oct 24"
        case "30 Minutes Before": return "Fri, Oct 24"
        case "1 Hour Before": return "Fri, Oct 24"
        default: return "Fri, Oct 24"
        }
    }

    // MARK: - Save / Reset

    private var saveControls: some View {
        VStack(spacing: 10) {
            Button {
                appState.showToast("Global defaults saved")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down.fill")
                    Text("Save Global Defaults")
                }
            }
            .buttonStyle(DSPrimaryButtonStyle(minHeight: 50))

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    settings.resetReminderDefaults()
                }
                appState.showToast("Reset to system recommendations")
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset to System Recommendations")
                }
                .font(DSTypography.labelChip())
                .foregroundStyle(Color.dsMutedForeground)
            }
            .buttonStyle(.plain)
        }
    }
}
