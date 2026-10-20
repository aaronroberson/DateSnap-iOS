import SwiftUI
import SwiftData

// MARK: - Engine Route Badge
/// States how the scan was interpreted. Apple Intelligence is named only when the on-device model actually ran.
struct EngineRouteBadge: View {
    let route: EngineRoute

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: route == .onDeviceModel ? "wand.and.sparkles" : "cpu")
                .font(.system(size: 12, weight: .semibold))
            Text(route == .onDeviceModel ? "Interpreted on device with Apple Intelligence" : "Read by Pencil’d's on-device rules")
                .font(PDFont.bodySM)
        }
        .foregroundStyle(route == .onDeviceModel ? Color.pdPrimary : Color.pdOnSurfaceVariant)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.pdSurfaceHighest))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Provenance Chip
/// Icon + label + color for where a field came from (never color alone).
struct ProvenanceChip: View {
    let provenance: FieldProvenance
    var needsCheck: Bool = false

    private var style: (label: String, icon: String, color: Color) {
        if needsCheck { return ("Please check", "exclamationmark.triangle.fill", .pdWarning) }
        switch provenance {
        case .explicitText: return ("From source text", "checkmark.seal.fill", .pdSuccess)
        case .deterministicRule, .modelInterpretation: return ("Inferred", "sparkles", .pdInfo)
        case .fallbackDefault: return ("Please check", "exclamationmark.triangle.fill", .pdWarning)
        case .userEdited: return ("Edited", "pencil", .pdSecondary)
        }
    }

    var body: some View {
        let style = style
        HStack(spacing: 4) {
            Image(systemName: style.icon).font(.system(size: 10, weight: .bold))
            Text(style.label).font(PDFont.bodySM)
        }
        .foregroundStyle(style.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Source: \(style.label)")
    }
}

// MARK: - Question Card
/// One-tap answer for a choice that materially changes the saved event.
struct AmbiguityQuestionCard: View {
    let question: AmbiguityQuestion
    let onSelect: (AmbiguityQuestion.Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(question.prompt, systemImage: "questionmark.bubble.fill")
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdOnSurface)
            FlowButtons(options: question.options, onSelect: onSelect)
            Text("You can still edit any field below.")
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceContainerHigh)
                .overlay(RoundedRectangle(cornerRadius: PDRadius.card).stroke(Color.pdWarning.opacity(0.35), lineWidth: 1))
        )
    }

    private struct FlowButtons: View {
        let options: [AmbiguityQuestion.Option]
        let onSelect: (AmbiguityQuestion.Option) -> Void

        var body: some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
        }

        @ViewBuilder
        private var buttons: some View {
            ForEach(options) { option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option.label)
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdSurface)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Color.pdWarning))
                }
            }
        }
    }
}

// MARK: - Alternatives
/// Compact cards for materially different readings. Choosing one fills the draft; it never saves a second event.
struct AlternativeInterpretationsCard: View {
    let alternatives: [EventInterpretationCandidate]
    let onUse: (EventInterpretationCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PDSectionHeader(title: "Other interpretations", trailing: "Choose a reading")
            }
            ForEach(alternatives) { alternative in
                Button {
                    onUse(alternative)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        PDIconTile(systemName: "arrow.triangle.branch", tint: .pdSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alternative.title.value)
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdOnSurface)
                                .lineLimit(1)
                            Text(alternative.start.value.formatted(alternative.isAllDay
                                ? .dateTime.weekday(.abbreviated).month(.abbreviated).day()
                                : .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                            if let reason = alternative.start.reason ?? alternative.title.reason {
                                Text(reason)
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer()
                        Label("Switch", systemImage: "arrow.left.arrow.right")
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdPrimary)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(Color.pdSurfaceHighest))
                    }
                    .padding(10)
                    .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLow))
                }
                .accessibilityHint("Fills the form with this reading")
            }
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }
}

// MARK: - Why This?
struct WhyThisSection: View {
    let rows: [(field: String, reason: String, source: String?)]
    var expandOnRequest: Int = 0
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "text.magnifyingglass").foregroundStyle(Color.pdSecondary)
                    Text("Why Pencil’d chose these details")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
            }
            if expanded {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.field.uppercased())
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        Text(row.reason)
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurface)
                        if let source = row.source {
                            Text("“\(source)”")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.pdSecondary.opacity(0.85))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceLowest))
                }
            }
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
        .onChange(of: expandOnRequest) { _, _ in expanded = true }
    }
}

// MARK: - Duplicate Banner
struct PossibleDuplicateBanner: View {
    let matches: [EventSimilarityService.Match]
    let onOpen: (String) -> Void
    let onKeepSeparate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This may match an event already saved", systemImage: "square.on.square")
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdOnSurface)
            ForEach(matches, id: \.entry.id) { match in
                Text("\(match.entry.title) · \(match.entry.start.formatted(date: .abbreviated, time: .shortened)) — \(match.reason)")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            HStack(spacing: 10) {
                if let first = matches.first {
                    Button("Open Saved Event") { onOpen(first.entry.id) }
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                }
                Spacer()
                Button("Keep Separate", action: onKeepSeparate)
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .frame(minHeight: 44)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdInfo.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: PDRadius.card).stroke(Color.pdInfo.opacity(0.35), lineWidth: 1))
        )
    }
}

// MARK: - Actions Checklist
/// RSVP / tickets / registration found on the flyer. Links open only when tapped.
struct EventActionsChecklist: View {
    let actions: [ActionSuggestion]
    let deadlineReminderDate: Date?
    @Binding var deadlineReminderEnabled: Bool
    let isEntitledToDeadlineReminders: Bool
    let onUpgrade: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "On the flyer")
            VStack(alignment: .leading, spacing: 10) {
                ForEach(actions) { action in
                    HStack(spacing: 10) {
                        Image(systemName: icon(for: action.kind))
                            .foregroundStyle(Color.pdSecondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.title)
                                .font(PDFont.bodyMD)
                                .foregroundStyle(Color.pdOnSurface)
                            if let deadline = action.deadline {
                                Text("By \(deadline.formatted(date: .abbreviated, time: .omitted))")
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdWarning)
                            }
                            if !action.target.isEmpty {
                                Text(action.target)
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if let url = url(for: action) {
                            Button("Open") { openURL(url) }
                                .font(PDFont.labelMD)
                                .foregroundStyle(Color.pdPrimary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
                if let deadlineReminderDate {
                    PDRowDivider()
                    if isEntitledToDeadlineReminders {
                        Toggle(isOn: $deadlineReminderEnabled) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Remind me to RSVP")
                                    .font(PDFont.bodyMD)
                                    .foregroundStyle(Color.pdOnSurface)
                                Text(deadlineReminderDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                        }
                        .toggleStyle(PDToggleStyle())
                    } else {
                        Button(action: onUpgrade) {
                            Label("RSVP-deadline reminders with Premium", systemImage: "lock.fill")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minHeight: 44)
                        }
                    }
                }
            }
            .padding(14)
            .pdGlassCard(cornerRadius: PDRadius.card)
        }
    }

    private func icon(for kind: ActionSuggestion.Kind) -> String {
        switch kind {
        case .rsvp: return "envelope.open.fill"
        case .buyTickets: return "ticket.fill"
        case .register: return "person.badge.plus"
        case .call: return "phone.fill"
        case .email: return "envelope.fill"
        case .website: return "safari.fill"
        }
    }

    private func url(for action: ActionSuggestion) -> URL? {
        Self.validatedActionURL(for: action)
    }

    static func validatedActionURL(for action: ActionSuggestion) -> URL? {
        let allowedSchemes: Set<String> = ["http", "https", "tel", "mailto"]
        let rawURL: URL?
        switch action.kind {
        case .call:
            let digits = action.target.filter { $0.isNumber || $0 == "+" }
            rawURL = digits.isEmpty ? nil : URL(string: "tel:\(digits)")
        case .email:
            let trimmed = action.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains(" ") else { return nil }
            rawURL = URL(string: "mailto:\(trimmed)")
        default:
            rawURL = NotificationService.validatedLink(action.target)
        }

        guard let url = rawURL,
              let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            return nil
        }
        return url
    }
}

// MARK: - Suggestions
/// Editable suggestions: duration, reminder plan, and an opt-in repeat. Renders nothing (no
/// heading) when there is nothing to suggest for this event.
struct ReviewSuggestionsCard: View {
    @ObservedObject var viewModel: EventReviewViewModel
    let isEntitledToReminderPlans: Bool
    let onUpgrade: () -> Void
    @Query(sort: \EventCandidate.startDate) private var candidates: [EventCandidate]

    /// A reminder plan worth offering: non-empty and different from the alerts already chosen.
    private var suggestedPlan: ReminderPlan? {
        let plan = viewModel.reminderPlan
        guard !plan.offsets.isEmpty,
              plan.offsets.map(\.timeInterval) != viewModel.selectedOffsets.map(\.timeInterval) else { return nil }
        return plan
    }

    var body: some View {
        let duration = viewModel.suggestedDuration
        let plan = suggestedPlan
        let signal = viewModel.recurrenceSignal
        if viewModel.isOpenEndedEvent || duration != nil || plan != nil || signal != nil {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                PDSectionHeader(title: "Suggestions", trailing: "Nothing changes until you tap")
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.isOpenEndedEvent {
                        OpenEndedConflictRadarCard(viewModel: viewModel, candidates: candidates)
                    }
                    if let duration {
                        suggestionRow(
                            icon: "clock.arrow.circlepath",
                            title: "End at \(viewModel.startDate.addingTimeInterval(duration).formatted(date: .omitted, time: .shortened))",
                            detail: "\(viewModel.category.displayName) events usually run \(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .wide))). Use sets the end time.",
                            actionTitle: "Use"
                        ) { viewModel.applySuggestedDuration() }
                    }

                    if let plan {
                        if isEntitledToReminderPlans {
                            suggestionRow(
                                icon: "bell.badge",
                                title: "Alerts: " + plan.offsets.map(\.label).joined(separator: ", "),
                                detail: plan.rationale + " Use replaces your current alerts.",
                                actionTitle: "Use"
                            ) { viewModel.applyReminderPlan() }
                        } else {
                            suggestionRow(
                                icon: "bell.badge",
                                title: "Tailored alerts for this event",
                                detail: "Premium suggests an alert plan based on the kind of event.",
                                actionTitle: "Premium",
                                action: onUpgrade
                            )
                        }
                    }

                    if let signal, signal.kind != .series {
                        Toggle(isOn: Binding(
                            get: { viewModel.repeatSelection == signal.kind },
                            set: { viewModel.repeatSelection = $0 ? signal.kind : nil }
                        )) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Repeat \(signal.kind == .weekly ? "weekly" : "monthly") in Calendar")
                                    .font(PDFont.bodyMD)
                                    .foregroundStyle(Color.pdOnSurface)
                                Text("Source says “\(signal.phrase)”. Off saves a single event.")
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                        }
                        .toggleStyle(PDToggleStyle())
                    } else if let signal {
                        Label("Part of a series (“\(signal.phrase)”). Saved as a single event.", systemImage: "square.stack.3d.up")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
                .padding(14)
                .pdGlassCard(cornerRadius: PDRadius.card)
            }
        }
    }

    private func suggestionRow(icon: String, title: String, detail: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.pdSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurface)
                Text(detail)
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            Spacer()
            Button(actionTitle, action: action)
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdPrimary)
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}

private struct OpenEndedConflictRadarCard: View {
    @ObservedObject var viewModel: EventReviewViewModel
    let candidates: [EventCandidate]
    @State private var assumption: EventReviewViewModel.OpenEndedDurationAssumption = .oneHour

    private var incoming: ScheduleInterval {
        let duration: TimeInterval = assumption == .twoHours ? 2 * 3600 : 3600
        return ScheduleConflictAnalyzer.interval(
            id: viewModel.candidate.id,
            title: viewModel.title,
            start: viewModel.startDate,
            end: assumption == .openEnded ? nil : viewModel.startDate.addingTimeInterval(duration),
            assumedDuration: duration,
            location: viewModel.location
        )
    }

    private var existing: [ScheduleInterval] {
        candidates.compactMap { candidate in
            guard candidate.id != viewModel.candidate.id,
                  candidate.savedEvent?.status == .saved,
                  !candidate.isAllDay else { return nil }
            return ScheduleConflictAnalyzer.interval(
                id: candidate.id,
                title: candidate.title,
                start: candidate.startDate,
                end: candidate.endDate,
                assumedDuration: EventDurationPolicy.fallback,
                location: candidate.location
            )
        }
    }

    private var conflicts: [ScheduleConflict] {
        ScheduleConflictAnalyzer.conflicts(for: incoming, against: existing)
    }

    private var sourceLabel: String {
        viewModel.candidate.scannedAsset?.sourceMedium.rawValue ?? "Local review"
    }

    private var ocrLabel: String {
        let score = viewModel.candidate.scannedAsset?.ocrConfidence ?? viewModel.confidenceScore
        return String(format: "%.1f%% OCR", score * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Conflict Radar", systemImage: "radar")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Spacer()
                Text("AI-assisted")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdPrimary)
            }

            HStack(spacing: 6) {
                badge(sourceLabel, tint: .pdPrimary)
                badge(ocrLabel, tint: .pdSecondary)
                badge("End time missing", tint: .pdTertiary)
            }

            Text("Open-ended overlap detected")
                .font(PDFont.headlineMD)
                .foregroundStyle(Color.pdOnSurface)
            Text("This scan starts at \(viewModel.startDate.formatted(date: .omitted, time: .shortened)) without a published end time. Check your local Pencil’d schedule before saving.")
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            if conflicts.isEmpty {
                Label("No local collisions in the selected horizon", systemImage: "checkmark.circle")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdSuccess)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("\(conflicts.count) local schedule risk\(conflicts.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdError)
                    ForEach(conflicts.prefix(3)) { conflict in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: conflict.kind == .overlap ? "arrow.left.and.right" : "figure.walk")
                                .foregroundStyle(conflict.kind == .overlap ? Color.pdError : Color.pdWarning)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conflict.event.title)
                                    .font(PDFont.bodyMD)
                                    .foregroundStyle(Color.pdOnSurface)
                                Text(conflict.kind == .overlap ? "Overlaps this assumed time block" : "Only \(Int((conflict.gap ?? 0) / 60))m between events")
                                    .font(PDFont.bodySM)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdError.opacity(0.10)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a duration assumption")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Picker("Duration assumption", selection: $assumption) {
                    Text("1 hour").tag(EventReviewViewModel.OpenEndedDurationAssumption.oneHour)
                    Text("2 hours").tag(EventReviewViewModel.OpenEndedDurationAssumption.twoHours)
                    Text("Open-ended").tag(EventReviewViewModel.OpenEndedDurationAssumption.openEnded)
                }
                .pickerStyle(.segmented)
                Button {
                    viewModel.applyDurationAssumption(assumption)
                } label: {
                    Label(assumption == .openEnded ? "Pencil in as flexible" : "Apply assumption and pencil in", systemImage: "edit_calendar")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(PDGradientButtonStyle())
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.7)))

            Text("Analysis uses saved Pencil’d events on this device. Apple Calendar-wide conflicts require Calendar read access and are not claimed here.")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .padding(14)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    private func badge(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(PDFont.labelSM)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.14)))
    }
}
