import SwiftUI
import SwiftData

/// Edits up to three alert offsets for an event and shows the save result.
struct ReminderScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let eventStart: Date
    let isAllDay: Bool
    let onSave: @MainActor ([ReminderOffset]) async -> MutationResult
    
    @State private var selectedPreset: ReminderPreset
    @State private var offsets: [ReminderOffset]
    @State private var isSyncing: Bool = false
    @State private var syncCompleted: Bool = false
    @State private var resultMessage: String?
    
    init(
        title: String,
        eventStart: Date,
        isAllDay: Bool,
        initialOffsets: [ReminderOffset],
        onSave: @escaping @MainActor ([ReminderOffset]) async -> MutationResult
    ) {
        self.title = title
        self.eventStart = eventStart
        self.isAllDay = isAllDay
        self.onSave = onSave
        self._offsets = State(initialValue: Array(initialOffsets.prefix(3)))
        self._selectedPreset = State(initialValue: Self.preset(matching: initialOffsets))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Top Bar
                        HStack {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color.dsSecondary)
                                    .frame(width: 44, height: 44)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.dsPrimary)
                                Text("DateSnap")
                                    .font(DSTypography.headlineCard())
                                    .foregroundStyle(Color.dsForeground)
                            }
                            
                            Spacer()
                            
                            Text("Reminder Schedule")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        // Screen Intro / Event Anchor
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Circle().fill(Color.dsPrimary).frame(width: 6, height: 6)
                                Text("REMINDER ALERTS")
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.dsPrimary)
                                Text("\(title) · \(eventStart.formatted(date: .abbreviated, time: isAllDay ? .omitted : .shortened))")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsSecondary)
                            }
                            
                            Text("Reminder Schedule")
                                .font(DSTypography.displayTitle())
                                .foregroundStyle(Color.dsForeground)
                            
                            Text("Configure multi-stage alerts so you never miss ticket drops, preparation windows, or final departure.")
                                .font(DSTypography.bodyCompact())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        
                        // Quick Presets Carousel
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("REMINDER PRESETS")
                                    .font(DSTypography.overlineConfidence())
                                    .foregroundStyle(Color.dsMutedForeground)
                                Spacer()
                                Text("Customizable")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsPrimary)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    presetPill(title: "Default (2 alerts)", icon: "sparkles", preset: .defaultPreset)
                                    presetPill(title: "Travel Heavy (3 alerts)", icon: "airplane.departure", preset: .travelHeavy)
                                    presetPill(title: "Day-of Only", icon: "calendar.badge.clock", preset: .dayOfOnly)
                                    presetPill(title: "Custom", icon: "slider.horizontal.3", preset: .custom)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Configured Reminder Rows (Up to 3 Interactive Glass Cards)
                        VStack(spacing: 14) {
                            ForEach(Array(offsets.enumerated()), id: \.element.id) { index, offset in
                                VStack(spacing: 10) {
                                    HStack {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(alertColor(for: index).opacity(0.18))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: alertIcon(for: index))
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(alertColor(for: index))
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("ALERT \(index + 1)")
                                                    .font(DSTypography.overlineConfidence())
                                                    .foregroundStyle(Color.dsMutedForeground)
                                                Menu {
                                                    ForEach(ReminderOffset.catalog) { option in
                                                        Button(option.label) {
                                                            offsets[index] = option
                                                            selectedPreset = Self.preset(matching: offsets)
                                                        }
                                                        .disabled(offsets.contains(where: { $0.timeInterval == option.timeInterval }))
                                                    }
                                                } label: {
                                                    HStack(spacing: 4) {
                                                        Text(offset.label)
                                                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                                                    }
                                                    .font(DSTypography.headlineCard())
                                                    .foregroundStyle(Color.dsForeground)
                                                }
                                                .accessibilityLabel("Alert \(index + 1), \(offset.label). Change timing")
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                                offsets.remove(at: index)
                                                selectedPreset = Self.preset(matching: offsets)
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .font(.system(size: 14))
                                                .foregroundStyle(Color.dsMutedForeground)
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(Color.white.opacity(0.06)))
                                        }
                                        .accessibilityLabel("Remove alert \(index + 1)")
                                    }
                                    
                                    // Detail strip & selectors
                                    VStack(spacing: 8) {
                                        HStack {
                                            HStack(spacing: 4) {
                                                Image(systemName: "clock")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.dsSecondary)
                                                Text("Scheduled for")
                                                    .font(DSTypography.caption())
                                                    .foregroundStyle(Color.dsMutedForeground)
                                            }
                                            Spacer()
                                            Text(scheduledText(for: offset))
                                                .font(DSTypography.labelChip())
                                                .foregroundStyle(Color.dsForeground)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.08)))
                                        }
                                        
                                        HStack {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bell.badge")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.dsSecondary)
                                                Text("Channel")
                                                    .font(DSTypography.caption())
                                                    .foregroundStyle(Color.dsMutedForeground)
                                            }
                                            Spacer()
                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar.badge.clock")
                                                    .font(.system(size: 11))
                                                Text("Calendar · Reminders · Alert")
                                                    .font(DSTypography.caption())
                                            }
                                            .foregroundStyle(Color.dsSecondary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.white.opacity(0.08)))
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.black.opacity(0.3))
                                    .cornerRadius(12)
                                }
                                .padding(14)
                                .dsGlassCard(cornerRadius: 20)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Add Alert Action & Limit Indicator
                        VStack(spacing: 6) {
                            if offsets.count >= 3 {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle")
                                    Text("Alert Limit Reached (3 of 3 max)")
                                }
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsMutedForeground.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(16)
                            } else {
                                Button {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        addNextAlert()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("+ Add Alert (\(offsets.count) of 3 active)")
                                    }
                                    .font(DSTypography.labelChip())
                                    .foregroundStyle(Color.dsPrimary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(16)
                                }
                            }
                            
                            Text("Tiered notifications prevent calendar alert fatigue while safeguarding essential arrival windows.")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsSecondary.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.horizontal)
                        
                        // Timed vs All-Day Logic Card
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "info")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.dsPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Timed vs. All-Day Logic")
                                    .font(DSTypography.bodyStrong())
                                    .foregroundStyle(Color.dsForeground)
                                Text("Timed events trigger at precise temporal countdown offsets. If an event is designated as all-day, reminder tiers calibrate automatically to 9:00 AM local time on designated offset days.")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(16)
                        .dsGlassCard(cornerRadius: 20)
                        .padding(.horizontal)
                        .padding(.bottom, 120)
                    }
                }
                
                // Sticky Bottom Actions
                VStack(spacing: 10) {
                    Button {
                        isSyncing = true
                        Task {
                            let sorted = offsets.sorted { $0.timeInterval < $1.timeInterval }
                            let result = await onSave(sorted)
                            isSyncing = false
                            switch result {
                            case .success:
                                syncCompleted = true
                                try? await Task.sleep(for: .milliseconds(600))
                                dismiss()
                            case .partial(let issues):
                                resultMessage = "Schedule saved with issues: \(issues.joined(separator: "; "))"
                            case .failure(let error):
                                resultMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSyncing {
                                ProgressView().tint(Color.dsPrimaryForeground)
                                Text("Syncing Schedule...")
                            } else if syncCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Schedule Synced!")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text(offsets.isEmpty ? "Save Without Alerts" : "Save Reminder Schedule")
                            }
                        }
                    }
                    .buttonStyle(DSPrimaryButtonStyle())
                    .disabled(isSyncing)
                    
                    HStack {
                        Button {
                            applyPreset(.defaultPreset)
                        } label: {
                            Text("Reset to Default")
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        
                        Spacer()
                        
                        Button {
                            dismiss()
                        } label: {
                            Text("Discard Changes")
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsError.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .background(Color.dsBackground.opacity(0.95))
            }
            .dsScreenBackground()
        }
        .alert("Reminder Schedule", isPresented: Binding(
            get: { resultMessage != nil },
            set: { if !$0 { resultMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultMessage ?? "")
        }
    }
    
    @ViewBuilder
    private func presetPill(title: String, icon: String, preset: ReminderPreset) -> some View {
        let isSel = selectedPreset == preset
        Button {
            selectedPreset = preset
            applyPreset(preset)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(DSTypography.labelChip())
            }
            .foregroundStyle(isSel ? Color.dsPrimaryForeground : Color.dsForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSel ? Color.dsPrimary : Color.white.opacity(0.08))
            )
        }
    }
    
    private func alertColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 123/255, green: 97/255, blue: 255/255)
        case 1: return Color(red: 255/255, green: 138/255, blue: 61/255)
        default: return Color.dsSuccess
        }
    }
    
    private func alertIcon(for index: Int) -> String {
        switch index {
        case 0: return "archivebox.fill"
        case 1: return "figure.walk"
        default: return "bolt.fill"
        }
    }
    
    private func scheduledText(for offset: ReminderOffset) -> String {
        let fire = offset.triggerDate(forEventStart: eventStart, isAllDay: isAllDay)
        let text = fire.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        return fire < Date() ? "\(text) (passed)" : text
    }

    private static func offsets(for preset: ReminderPreset) -> [ReminderOffset]? {
        switch preset {
        case .defaultPreset: return [.oneDayBefore, .twoHoursBefore]
        case .travelHeavy: return [.twoDaysBefore, .threeHoursBefore, .fortyFiveMinutesBefore]
        case .dayOfOnly: return [.twoHoursBefore]
        case .custom: return nil
        }
    }

    private static func preset(matching offsets: [ReminderOffset]) -> ReminderPreset {
        let intervals = offsets.map(\.timeInterval).sorted()
        for preset in ReminderPreset.allCases {
            if let presetOffsets = Self.offsets(for: preset), presetOffsets.map(\.timeInterval).sorted() == intervals {
                return preset
            }
        }
        return .custom
    }

    private func applyPreset(_ preset: ReminderPreset) {
        selectedPreset = preset
        if let presetOffsets = Self.offsets(for: preset) {
            offsets = presetOffsets
        }
    }

    private func addNextAlert() {
        guard offsets.count < 3 else { return }
        let used = Set(offsets.map(\.timeInterval))
        let preferred: [ReminderOffset] = [.oneDayBefore, .twoHoursBefore, .thirtyMinutesBefore]
        if let next = (preferred + ReminderOffset.catalog).first(where: { !used.contains($0.timeInterval) }) {
            offsets.append(next)
        }
        selectedPreset = Self.preset(matching: offsets)
    }
}

// MARK: - Saved Event Schedule Editor
/// Reschedules alerts on an already-saved event (Calendar alarms, the reminder, and local notifications).
struct SavedEventScheduleEditor: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    let event: DateSnapEvent

    var body: some View {
        if let saved = SavedEventActions.savedEvent(candidateId: event.id, in: modelContext),
           let candidate = saved.candidate {
            ReminderScheduleEditorView(
                title: candidate.title,
                eventStart: candidate.startDate,
                isAllDay: candidate.isAllDay,
                initialOffsets: saved.alertOffsets.map { ReminderOffset.forInterval($0) }
            ) { offsets in
                let actions = SavedEventActions(services: services, modelContext: modelContext)
                let result = await actions.rescheduleAlerts(for: saved, offsets: offsets)
                if case .success = result {
                    appState.showToast("Reminder schedule updated (\(offsets.count) alert\(offsets.count == 1 ? "" : "s"))")
                }
                return result
            }
        } else {
            Text("This event is no longer available")
                .font(DSTypography.bodyStrong())
                .foregroundStyle(Color.dsForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dsScreenBackground()
        }
    }
}
