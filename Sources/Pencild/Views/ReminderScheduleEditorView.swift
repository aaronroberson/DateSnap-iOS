import SwiftUI
import SwiftData

/// Edits the existing production alert offsets and reports the actual save result.
struct ReminderScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let eventStart: Date
    let isAllDay: Bool
    let onSave: @MainActor ([ReminderOffset]) async -> MutationResult

    @State private var selectedPreset: ReminderPreset
    @State private var offsets: [ReminderOffset]
    @State private var isSyncing = false
    @State private var syncCompleted = false
    @State private var resultMessage: String?

    init(title: String, eventStart: Date, isAllDay: Bool, initialOffsets: [ReminderOffset],
         onSave: @escaping @MainActor ([ReminderOffset]) async -> MutationResult) {
        self.title = title
        self.eventStart = eventStart
        self.isAllDay = isAllDay
        self.onSave = onSave
        self._offsets = State(initialValue: Array(initialOffsets.prefix(3)))
        self._selectedPreset = State(initialValue: Self.preset(matching: initialOffsets))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDTopBar(title: "Reminder schedule")
                    PDScreenIntro(eyebrow: "REMINDER ALERTS", title: "Reminder Schedule", subtitle: "Choose when Pencil'd should remind you about this event.")
                    summary
                    presets
                    VStack(alignment: .leading, spacing: PDSpacing.sm) {
                        PDSectionHeader(title: "Your alert schedule", trailing: "\(offsets.count) of 3")
                        ForEach(Array(offsets.enumerated()), id: \.element.id) { index, offset in
                            alertCard(index: index, offset: offset)
                        }
                        if offsets.isEmpty {
                            PDCard {
                                Label("No alerts configured", systemImage: "bell.slash")
                                    .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                        }
                        Button { addNextAlert() } label: {
                            Label("Add another alert", systemImage: "plus.circle")
                                .font(PDFont.labelLG).foregroundStyle(Color.pdSecondary)
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Color.pdSurfaceLow, in: RoundedRectangle(cornerRadius: PDRadius.card))
                        }
                        .disabled(offsets.count >= 3)
                        .opacity(offsets.count >= 3 ? 0.5 : 1)
                        Text("Up to three alerts per event. Choosing no alerts removes the current schedule.")
                            .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    PDCard {
                        HStack(alignment: .top, spacing: PDSpacing.sm) {
                            PDIconTile(systemName: "info.circle", tint: .pdInfo)
                            Text(isAllDay ? "All-day alerts use 9:00 AM local time on the offset day. Times that have already passed will not create new Pencil'd notifications." : "Alert times follow the event start. Times that have already passed will not create new Pencil'd notifications.")
                                .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                }
                .padding(PDSpacing.md)
                .padding(.bottom, PDSpacing.md)
                .disabled(isSyncing || syncCompleted)
            }
            .safeAreaInset(edge: .bottom) { saveActions }
            .dsScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .alert("Reminder schedule", isPresented: Binding(
            get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(resultMessage ?? "") }
    }

    private var summary: some View {
        PDCard(highlighted: true) {
            HStack(alignment: .top, spacing: PDSpacing.md) {
                PDIconTile(systemName: "calendar.badge.clock", size: .large)
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    Text(title).font(PDFont.headlineSM).foregroundStyle(Color.pdOnSurface)
                    Text(eventStart.formatted(date: .complete, time: isAllDay ? .omitted : .shortened))
                        .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    if isAllDay {
                        PDStatusBadge(text: "All-day event", icon: "sun.max", tone: .info)
                    }
                    Label("\(offsets.count) configured alert\(offsets.count == 1 ? "" : "s")", systemImage: "bell")
                        .font(PDFont.labelMD).foregroundStyle(Color.pdSecondary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Quick presets")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PDSpacing.sm) {
                    ForEach(ReminderPreset.allCases) { preset in
                        Button { applyPreset(preset) } label: {
                            PDCard(highlighted: selectedPreset == preset) {
                                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                                    HStack {
                                        PDIconTile(systemName: preset.icon, tint: .pdSecondary)
                                        Spacer()
                                        if selectedPreset == preset { PDCheckmark(size: 20) }
                                    }
                                    Text(preset.rawValue).font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                                    Text(Self.offsets(for: preset)?.map(\.label).joined(separator: " · ") ?? "Edit each alert timing")
                                        .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(width: 180)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedPreset == preset ? .isSelected : [])
                    }
                }
            }
            if let presetOffsets = Self.offsets(for: selectedPreset) {
                Text(presetOffsets.map(\.label).joined(separator: " · "))
                    .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
            } else {
                Text("Adjust each alert below to create your own schedule.")
                    .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
    }

    private func alertCard(index: Int, offset: ReminderOffset) -> some View {
        PDCard {
            HStack(alignment: .top, spacing: PDSpacing.sm) {
                PDIconTile(systemName: "bell", tint: .pdSecondary, size: .large)
                VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                    Text("ALERT \(index + 1)").font(PDFont.labelSM).foregroundStyle(Color.pdOnSurfaceVariant)
                    Menu {
                        ForEach(ReminderOffset.catalog) { option in
                            Button(option.label) {
                                offsets[index] = option
                                selectedPreset = Self.preset(matching: offsets)
                            }
                            .disabled(offsets.enumerated().contains { $0.offset != index && $0.element.timeInterval == option.timeInterval })
                        }
                    } label: {
                        HStack(spacing: PDSpacing.sm) {
                            Text(offset.label).font(PDFont.headlineSM)
                            Image(systemName: "chevron.up.chevron.down").font(PDFont.labelSM)
                        }
                        .foregroundStyle(Color.pdOnSurface).frame(minHeight: 44)
                    }
                    .accessibilityLabel("Alert \(index + 1), \(offset.label). Change timing")
                    Text(scheduledText(for: offset)).font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer(minLength: 0)
                Button {
                    offsets.remove(at: index)
                    selectedPreset = Self.preset(matching: offsets)
                } label: {
                    Image(systemName: "trash").foregroundStyle(Color.pdError).frame(width: 44, height: 44)
                }
                .accessibilityLabel("Remove alert \(index + 1)")
            }
        }
    }

    private var saveActions: some View {
        VStack(spacing: PDSpacing.sm) {
            Button { save() } label: {
                HStack(spacing: PDSpacing.sm) {
                    if isSyncing { ProgressView().tint(Color.pdOnPrimaryFixed) }
                    else { Image(systemName: syncCompleted ? "checkmark.circle.fill" : "checkmark") }
                    Text(isSyncing ? "Saving schedule…" : syncCompleted ? "Schedule saved" : offsets.isEmpty ? "Save without alerts" : "Save reminder schedule")
                }
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(isSyncing || syncCompleted)
            HStack {
                Button("Reset to default") { applyPreset(.defaultPreset) }
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Spacer()
                Button("Discard changes") { dismiss() }.foregroundStyle(Color.pdError)
            }
            .font(PDFont.labelMD).frame(minHeight: 44)
            .disabled(isSyncing || syncCompleted)
        }
        .padding(PDSpacing.md)
        .background(Color.pdSurfaceLow)
    }

    private func save() {
        isSyncing = true
        Task {
            let result = await onSave(offsets.sorted { $0.timeInterval < $1.timeInterval })
            isSyncing = false
            switch result {
            case .success:
                syncCompleted = true
                try? await Task.sleep(for: .milliseconds(600))
                dismiss()
            case .partial(let issues): resultMessage = "Schedule saved with issues: \(issues.joined(separator: "; "))"
            case .failure(let error): resultMessage = error.localizedDescription
            }
        }
    }

    private func scheduledText(for offset: ReminderOffset) -> String {
        let fire = offset.triggerDate(forEventStart: eventStart, isAllDay: isAllDay)
        let text = fire.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        return fire < Date() ? "\(text) (passed)" : text
    }

    private static func offsets(for preset: ReminderPreset) -> [ReminderOffset]? {
        switch preset {
        case .defaultPreset: return ReminderOffset.defaultStaggered
        case .travelHeavy: return [.twoDaysBefore, .threeHoursBefore, .fortyFiveMinutesBefore]
        case .dayOfOnly: return [.twoHoursBefore]
        case .custom: return nil
        }
    }

    private static func preset(matching offsets: [ReminderOffset]) -> ReminderPreset {
        let intervals = offsets.map(\.timeInterval).sorted()
        for preset in ReminderPreset.allCases {
            if let presetOffsets = Self.offsets(for: preset), presetOffsets.map(\.timeInterval).sorted() == intervals { return preset }
        }
        return .custom
    }

    private func applyPreset(_ preset: ReminderPreset) {
        selectedPreset = preset
        if let presetOffsets = Self.offsets(for: preset) { offsets = presetOffsets }
    }

    private func addNextAlert() {
        guard offsets.count < 3 else { return }
        let used = Set(offsets.map(\.timeInterval))
        let preferred: [ReminderOffset] = [.oneDayBefore, .twoHoursBefore, .thirtyMinutesBefore]
        if let next = (preferred + ReminderOffset.catalog).first(where: { !used.contains($0.timeInterval) }) { offsets.append(next) }
        selectedPreset = Self.preset(matching: offsets)
    }
}

// MARK: - Saved Event Schedule Editor
/// Reschedules alerts on an already-saved event (Calendar alarms, the reminder, and local notifications).
struct SavedEventScheduleEditor: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    let event: PencildEvent

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
                .font(PDFont.headlineSM)
                .foregroundStyle(Color.pdOnSurface)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dsScreenBackground()
        }
    }
}
