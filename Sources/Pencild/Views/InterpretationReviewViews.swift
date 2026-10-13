import SwiftUI

// MARK: - Engine Route Badge
/// States how the scan was interpreted. Apple Intelligence is named only when the on-device model actually ran.
struct EngineRouteBadge: View {
    let route: EngineRoute

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: route == .onDeviceModel ? "wand.and.sparkles" : "cpu")
                .font(.system(size: 12, weight: .semibold))
            Text(route == .onDeviceModel ? "Interpreted on device with Apple Intelligence" : "Read by Pencil'd's on-device rules")
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
                    Text("Why Pencil’d chose these fields")
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
        VStack(alignment: .leading, spacing: 10) {
            Text("ON THE FLYER")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
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
/// Editable suggestions: duration, reminder plan, and an opt-in repeat.
struct ReviewSuggestionsCard: View {
    @ObservedObject var viewModel: EventReviewViewModel
    let isEntitledToReminderPlans: Bool
    let onUpgrade: () -> Void

    var body: some View {
        let plan = viewModel.reminderPlan
        let planDiffers = plan.offsets.map(\.timeInterval) != viewModel.selectedOffsets.map(\.timeInterval)
        if viewModel.suggestedDuration != nil || planDiffers || viewModel.recurrenceSignal != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("SUGGESTIONS")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)

                if let duration = viewModel.suggestedDuration {
                    suggestionRow(
                        icon: "clock.arrow.circlepath",
                        title: "Suggested duration: \(Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .wide)))",
                        detail: "Based on the \(viewModel.category.displayName.lowercased()) category; please review.",
                        actionTitle: "Use"
                    ) { viewModel.applySuggestedDuration() }
                }

                if planDiffers && !plan.offsets.isEmpty {
                    if isEntitledToReminderPlans {
                        suggestionRow(
                            icon: "bell.badge",
                            title: "Suggested alerts: " + plan.offsets.map(\.label).joined(separator: ", "),
                            detail: plan.rationale,
                            actionTitle: "Use"
                        ) { viewModel.applyReminderPlan() }
                    } else {
                        Button(action: onUpgrade) {
                            Label("Tailored alert plans with Premium", systemImage: "lock.fill")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minHeight: 44)
                        }
                    }
                }

                if let signal = viewModel.recurrenceSignal, signal.kind != .series {
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
                } else if let signal = viewModel.recurrenceSignal {
                    Label("Part of a series (“\(signal.phrase)”). Saved as a single event.", systemImage: "square.stack.3d.up")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            .padding(14)
            .pdGlassCard(cornerRadius: PDRadius.card)
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
