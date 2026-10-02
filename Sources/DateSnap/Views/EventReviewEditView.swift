import SwiftUI
import SwiftData
import EventKit

/// Entry point for reviewing a scanned (or saved) event. Resolves the persisted candidate behind the
/// `DateSnapEvent` and hands it to a form bound to `EventReviewViewModel`.
struct EventReviewEditView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let event: DateSnapEvent

    var body: some View {
        if let candidate = SavedEventActions.candidate(id: event.id, in: modelContext) {
            EventReviewForm(
                viewModel: EventReviewViewModel(
                    candidate: candidate,
                    services: services,
                    sourceImage: appState.sourceImages[candidate.id]
                )
            )
        } else {
            VStack(spacing: 14) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.dsMutedForeground)
                Text("This event is no longer available")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Button("Close") { dismiss() }
                    .buttonStyle(DSSecondaryButtonStyle())
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dsScreenBackground()
        }
    }
}

// MARK: - Review Form
struct EventReviewForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: EventReviewViewModel

    @State private var showOriginalDrawer: Bool = false
    @State private var showRawOcr: Bool = false
    @State private var showScheduleEditor: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var showDiscardConfirm: Bool = false
    @State private var duplicatesDismissed: Bool = false

    init(viewModel: @autoclosure @escaping () -> EventReviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    private var tier: ConfidenceTier { viewModel.confidenceTier }
    private var scorePercent: Int { Int((viewModel.confidenceScore * 100).rounded()) }
    private var rawLines: [String] {
        viewModel.rawText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        confidenceRow
                        if let route = viewModel.engineRoute {
                            EngineRouteBadge(route: route)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                        if !viewModel.duplicateMatches.isEmpty && !duplicatesDismissed {
                            PossibleDuplicateBanner(
                                matches: viewModel.duplicateMatches,
                                onOpen: openSavedEvent,
                                onKeepSeparate: { withAnimation { duplicatesDismissed = true } }
                            )
                            .padding(.horizontal)
                        }
                        ForEach(viewModel.openQuestions) { question in
                            AmbiguityQuestionCard(question: question) { option in
                                withAnimation { viewModel.answer(question, with: option) }
                            }
                            .padding(.horizontal)
                        }
                        if viewModel.isAmbiguousDate && !viewModel.openQuestions.contains(where: { $0.field == .date }) {
                            ambiguityBanner
                        }
                        sourceCard
                        if !viewModel.visibleAlternatives.isEmpty {
                            AlternativeInterpretationsCard(alternatives: viewModel.visibleAlternatives) { alternative in
                                withAnimation { viewModel.apply(alternative) }
                            }
                            .padding(.horizontal)
                        }
                        if !viewModel.whyThisRows.isEmpty {
                            WhyThisSection(rows: viewModel.whyThisRows)
                                .padding(.horizontal)
                        }
                        formSection
                    }
                }

                if showSuccessToast { successToast }
            }
            .dsScreenBackground()
            .sheet(isPresented: $showScheduleEditor) {
                ReminderScheduleEditorView(
                    title: viewModel.title,
                    eventStart: viewModel.startDate,
                    isAllDay: viewModel.isAllDay,
                    initialOffsets: viewModel.selectedOffsets
                ) { offsets in
                    viewModel.selectedOffsets = offsets
                    return .success
                }
            }
            .alert("Couldn't Save Event", isPresented: Binding(
                get: { viewModel.errorMessage != nil && !viewModel.calendarAccessDenied },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog("Discard this event?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    switch viewModel.discard(modelContext: modelContext) {
                    case .success:
                        appState.showToast("Event discarded")
                        dismiss()
                    case .partial(let issues):
                        appState.showToast("Event discard was incomplete: \(issues.joined(separator: "; "))")
                    case .failure:
                        break // The view model exposes the failure through its alert.
                    }
                }
            } message: {
                Text("It will be removed from your review queue. Nothing was added to your calendar.")
            }
            .task {
                viewModel.findDuplicates(in: modelContext)
                await viewModel.prepareDestinations()
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.dsSecondary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close")

            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dsPrimary)
                Text("DateSnap")
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
            }

            Spacer()

            Text(viewModel.isEditingSavedEvent ? "Edit Saved Event" : "Review Before Saving")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Confidence (Icon + Label + Color)
    private var confidenceRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: tier.hexColor))
                    .frame(width: 8, height: 8)
                Text("VERIFICATION STAGE")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsMutedForeground)
            }

            Spacer()

            HStack(spacing: 5) {
                Image(systemName: tier.iconName)
                    .font(.system(size: 11, weight: .bold))
                Text("\(scorePercent)% \(tier.label)")
                    .font(DSTypography.overlineConfidence())
            }
            .foregroundStyle(Color(hex: tier.hexColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: tier.hexColor).opacity(0.15))
                    .overlay(Capsule().stroke(Color(hex: tier.hexColor).opacity(0.3), lineWidth: 1))
            )
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal)
    }

    // MARK: - Ambiguous Date Swap Prompt
    private var ambiguityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(hex: "FFBE55"))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Ambiguous Date Detected")
                        .font(DSTypography.bodyCompact())
                        .fontWeight(.bold)
                        .foregroundStyle(Color.dsForeground)
                    if let frag = viewModel.ambiguousFragment {
                        Text("(\(frag))")
                            .font(DSTypography.caption())
                            .fontWeight(.bold)
                            .foregroundStyle(Color(hex: "FFBE55"))
                    }
                }
                Text("Read as \(viewModel.startDate.formatted(.dateTime.month(.wide).day())). Swap if day and month are reversed.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                Button("Keep this date") { viewModel.confirmDateOrder() }
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsSecondary)
                    .frame(minHeight: 44)
            }

            Spacer()

            Button {
                withAnimation { viewModel.swapMonthAndDay() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Swap")
                }
                .font(DSTypography.caption())
                .fontWeight(.bold)
                .foregroundStyle(Color.dsBackground)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color(hex: "FFBE55")))
            }
            .frame(minHeight: 44)
            .accessibilityLabel("Swap month and day")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "FFBE55").opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "FFBE55").opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Source Card
    private var sourceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let image = viewModel.sourceImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 79/255, blue: 179/255).opacity(0.7),
                                    Color(red: 91/255, green: 124/255, blue: 255/255).opacity(0.6),
                                    Color.dsBackground
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay(
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            )
                        }
                    }
                    .frame(width: 68, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("SOURCE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.dsSecondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.7)))
                        .padding(4)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.dsPrimary)
                        Text("READ ON-DEVICE")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsPrimary)
                    }

                    Text(viewModel.candidate.scannedAsset != nil ? "Scanned Image" : "Manual Entry")
                        .font(DSTypography.headlineCard())
                        .foregroundStyle(Color.dsForeground)

                    Text(viewModel.candidate.scannedAsset.map { "Scanned \($0.scannedAt.formatted(date: .abbreviated, time: .shortened))" } ?? "No source image")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)

                    if viewModel.sourceImage != nil {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showOriginalDrawer.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: showOriginalDrawer ? "eye.slash.fill" : "eye.fill")
                                Text(showOriginalDrawer ? "Hide Original" : "View Original")
                            }
                            .font(DSTypography.labelChip())
                            .foregroundStyle(Color.dsSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }

            if showOriginalDrawer, let image = viewModel.sourceImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsBackground.opacity(0.85)))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel("Original scanned image")
            }
        }
        .padding(16)
        .dsGlassCard(cornerRadius: 22, elevated: true, borderColor: Color.dsPrimary.opacity(0.2))
        .padding(.horizontal)
    }

    // MARK: - Editable Form
    private var formSection: some View {
        VStack(spacing: 14) {
            titleField
            dateCard
            locationCard
            notesCard
            if !rawLines.isEmpty { rawTextCard }
            ReviewSuggestionsCard(
                viewModel: viewModel,
                isEntitledToReminderPlans: appState.isEntitled(to: .advancedReminderPlans),
                onUpgrade: { Task { await appState.present(.premiumPaywall) } }
            )
            if !viewModel.actions.isEmpty {
                EventActionsChecklist(
                    actions: viewModel.actions,
                    deadlineReminderDate: viewModel.deadlineReminderDate,
                    deadlineReminderEnabled: $viewModel.deadlineReminderEnabled,
                    isEntitledToDeadlineReminders: appState.isEntitled(to: .advancedReminderPlans),
                    onUpgrade: { Task { await appState.present(.premiumPaywall) } }
                )
            }
            destinationCard
            #if DEBUG
            InterpretationDiagnosticsView(viewModel: viewModel)
            #endif
            actions
        }
        .padding(.horizontal)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EVENT TITLE")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsMutedForeground)
                Spacer()
                if let source = viewModel.provenance(for: .title) {
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dsPrimary)

                TextField("Enter event name...", text: $viewModel.title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)

                if !viewModel.title.isEmpty {
                    Button {
                        viewModel.title = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    .accessibilityLabel("Clear title")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.dsCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dsBorder, lineWidth: 1))
            )
        }
    }

    private var dateCard: some View {
        VStack(spacing: 12) {
            if let source = viewModel.provenance(for: .date) {
                HStack {
                    Text("WHEN")
                        .font(DSTypography.overlineConfidence())
                        .foregroundStyle(Color.dsMutedForeground)
                    Spacer()
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
            }
            dateRow(icon: "calendar", label: viewModel.isAllDay ? "DATE" : "STARTS") {
                DatePicker(
                    "Start",
                    selection: $viewModel.startDate,
                    displayedComponents: viewModel.isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .labelsHidden()
                .onChange(of: viewModel.startDate) { oldValue, _ in
                    viewModel.startDateChanged(from: oldValue)
                }
            }

            if !viewModel.isAllDay {
                Divider().background(Color.white.opacity(0.08))

                dateRow(icon: "clock", label: "ENDS") {
                    DatePicker(
                        "End",
                        selection: $viewModel.endDate,
                        in: viewModel.startDate...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                }
            }

            if viewModel.yearAssumed {
                Label("Year wasn't on the flyer — DateSnap picked the next upcoming one.", systemImage: "info.circle")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.white.opacity(0.08))

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("All-Day Event")
                        .font(DSTypography.bodyCompact())
                        .foregroundStyle(Color.dsForeground)
                    Text("Alerts fire at 9:00 AM on alert days")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }

                Spacer()

                Toggle("All-Day Event", isOn: $viewModel.isAllDay)
                    .labelsHidden()
                    .tint(Color.dsPrimary)
            }
        }
        .padding(16)
        .dsGlassCard(cornerRadius: 20)
    }

    @ViewBuilder
    private func dateRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(Color.dsSecondary)
            }

            Text(label)
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)

            Spacer()

            content()
                .tint(Color.dsPrimary)
                .colorScheme(.dark)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOCATION")
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsMutedForeground)
                if let source = viewModel.provenance(for: .venue) {
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
                Spacer()
                if let mapsURL {
                    Button {
                        openURL(mapsURL)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 10))
                            Text("Open in Maps")
                                .font(DSTypography.caption())
                        }
                        .foregroundStyle(Color.dsInfo)
                        .frame(minHeight: 44)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(Color.dsInfo)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Venue name", text: $viewModel.venueName)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    TextField("Address", text: $viewModel.location)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }

            if !viewModel.rsvpUrl.isEmpty || viewModel.candidate.rsvpUrl != nil {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(Color.dsSecondary)
                    TextField("Tickets / RSVP link", text: $viewModel.rsvpUrl)
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsForeground)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .dsGlassCard(cornerRadius: 20)
    }

    private var mapsURL: URL? {
        let query = [viewModel.venueName, viewModel.location].filter { !$0.isEmpty }.joined(separator: ", ")
        guard !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES & DETAILS")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)

            TextEditor(text: $viewModel.notes)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(8)
                .overlay(alignment: .topLeading) {
                    if viewModel.notes.isEmpty {
                        Text("Add notes (door times, dress code, tickets)…")
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsMutedForeground)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(14)
        .dsGlassCard(cornerRadius: 20)
    }

    private var rawTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showRawOcr.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(Color(red: 123/255, green: 97/255, blue: 255/255))
                    Text("Extracted Source Text (Raw OCR)")
                        .font(DSTypography.labelChip())
                        .foregroundStyle(Color.dsForeground)
                    Spacer()
                    Image(systemName: showRawOcr ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .frame(minHeight: 44)
            }

            if showRawOcr {
                VStack(alignment: .leading, spacing: 4) {
                    Text("# ON-DEVICE VISION OCR [CONFIDENCE: \(String(format: "%.2f", viewModel.confidenceScore))]")
                        .foregroundStyle(Color.dsSuccess)
                    ForEach(Array(rawLines.enumerated()), id: \.offset) { index, line in
                        Text("> LINE \(index + 1): \(line)")
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.dsSecondary.opacity(0.85))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
            }
        }
        .padding(14)
        .dsGlassCard(cornerRadius: 20)
    }

    // MARK: - Destination (Calendar, Reminders list, Alerts)
    private var destinationCard: some View {
        VStack(spacing: 12) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 2/255, green: 57/255, blue: 191/255).opacity(0.6))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Saving To Calendar")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                    if viewModel.availableCalendars.isEmpty {
                        Text("Default calendar (access requested on save)")
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                    } else {
                        Menu {
                            ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                                Button(calendar.title) { viewModel.selectedCalendar = calendar }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedCalendar?.title ?? "Choose calendar")
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                            }
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                        }
                    }
                }

                Spacer()
            }

            if !viewModel.availableReminderLists.isEmpty {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.dsInfo.opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: "checklist")
                            .foregroundStyle(Color.dsInfo)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Reminders List")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                        Menu {
                            ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                                Button(list.title) { viewModel.selectedReminderList = list }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedReminderList?.title ?? "Choose list")
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                            }
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                        }
                    }
                    Spacer()
                }
            }

            Button {
                showScheduleEditor = true
            } label: {
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.dsSecondary)
                    Text(viewModel.selectedOffsets.isEmpty ? "No alerts" : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsForeground)
                        .lineLimit(1)
                    Spacer()
                    Text("\(viewModel.selectedOffsets.count) Alert\(viewModel.selectedOffsets.count == 1 ? "" : "s")")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Edit alerts, \(viewModel.selectedOffsets.count) scheduled")
        }
        .padding(14)
        .dsGlassCard(cornerRadius: 20)
    }

    // MARK: - Actions
    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(Color.dsPrimaryForeground)
                        Text("Saving...")
                    } else {
                        Text(viewModel.isEditingSavedEvent ? "Update Calendar Event" : "Save Event to Calendar")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(viewModel.isSaving)

            if !viewModel.isEditingSavedEvent {
                HStack(spacing: 12) {
                    Button {
                        switch viewModel.saveDraft(modelContext: modelContext) {
                        case .success:
                            appState.showToast("Draft saved to Review Queue")
                            dismiss()
                        case .partial(let issues):
                            appState.showToast("Draft saved with issues: \(issues.joined(separator: "; "))")
                        case .failure:
                            break // The view model exposes the failure through its alert.
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark")
                                .foregroundStyle(Color.dsSecondary)
                            Text("Save Draft")
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.08))
                        )
                    }

                    Button {
                        if viewModel.candidate.savedEvent == nil {
                            showDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .foregroundStyle(Color.dsError)
                            Text(viewModel.candidate.savedEvent == nil ? "Discard" : "Close")
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsError)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.dsError.opacity(0.12))
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    private func openSavedEvent(_ candidateID: String) {
        guard let match = SavedEventActions.candidate(id: candidateID, in: modelContext) else { return }
        Task { await appState.present(.savedEventDetail(match.toDateSnapEvent())) }
    }

    private func save() async {
        let wasUpdate = viewModel.isEditingSavedEvent
        let result = await viewModel.commitEvent(modelContext: modelContext)
        switch result {
        case .failure:
            if viewModel.calendarAccessDenied {
                await appState.present(.calendarPermissionDenied)
            }
            return
        case .partial:
            // Keep the review visible so the surfaced alert explains which reminder action failed.
            return
        case .success:
            break
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showSuccessToast = true }
        try? await Task.sleep(for: .seconds(1.1))
        appState.showToast(wasUpdate ? "✓ Calendar event updated" : "✓ Event saved to Calendar & Reminders")
        await appState.present(.savedEventDetail(viewModel.candidate.toDateSnapEvent()))
    }

    private var successToast: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.dsSuccess.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.dsSuccess)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Saved to Apple Calendar")
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text("\(viewModel.selectedOffsets.count) alert\(viewModel.selectedOffsets.count == 1 ? "" : "s") scheduled.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.dsCardElevated)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.dsSuccess.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
