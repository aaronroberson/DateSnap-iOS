import SwiftUI
import SwiftData
import EventKit

/// Entry point for reviewing a scanned (or saved) event. Resolves the persisted candidate behind the
/// `PencildEvent` and hands it to a form bound to `EventReviewViewModel`.
struct EventReviewEditView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    let event: PencildEvent

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
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Text("This event is no longer available")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Button("Close") { dismiss() }
                    .buttonStyle(PDSecondaryButtonStyle())
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .pdScreenBackground()
        }
    }
}

// MARK: - Review Form
struct EventReviewForm: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState

    @StateObject private var viewModel: EventReviewViewModel

    @State private var showOriginalDrawer: Bool = false
    @State private var showRawOcr: Bool = false
    @State private var showScheduleEditor: Bool = false
    @State private var showSuccessToast: Bool = false
    @State private var showDiscardConfirm: Bool = false
    @State private var duplicatesDismissed: Bool = false
    @State private var scanDetailsRequests = 0
    @State private var showNotificationRecovery = false
    @State private var isCommitting = false
    @State private var lastSaveWasPartial = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var sourceViewport = SourceViewport()

    init(viewModel: @autoclosure @escaping () -> EventReviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    private var tier: ConfidenceTier { viewModel.confidenceTier }
    private var scorePercent: Int { Int((viewModel.confidenceScore * 100).rounded()) }
    private var rawLines: [String] {
        viewModel.rawText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if horizontalSizeClass == .regular && !viewModel.isManualEntry {
                    iPadDualPaneContent
                } else {
                    iPhoneSingleColumnContent
                }

                if showSuccessToast { successToast }
            }
            .frame(maxWidth: viewModel.isManualEntry && horizontalSizeClass == .regular ? 720 : .infinity)
            .frame(maxWidth: .infinity)
            .pdScreenBackground()
            .navigationBarHidden(true)
            .sheet(isPresented: $showScheduleEditor) {
                ReminderScheduleEditorView(
                    title: viewModel.title,
                    eventStart: viewModel.startDate,
                    isAllDay: viewModel.isAllDay,
                    initialOffsets: viewModel.selectedOffsets,
                    maxAlerts: viewModel.maxAlerts
                ) { offsets in
                    viewModel.selectedOffsets = offsets
                    return .success
                }
            }
            .sheet(isPresented: $showNotificationRecovery, onDismiss: {
                Task { await appState.present(.savedEventDetail(viewModel.candidate.toPencildEvent())) }
            }) {
                NotificationPermissionDeniedView()
            }
            .alert(lastSaveWasPartial ? "Saved with incomplete reminders" : "Couldn't Save Event", isPresented: Binding(
                get: { !isCommitting && viewModel.errorMessage != nil && !viewModel.calendarAccessDenied },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog("Discard this event?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    let result = viewModel.discard(modelContext: modelContext)
                    guard case .success = result else { return }
                    appState.showToast("Event discarded")
                    dismiss()
                }
            } message: {
                Text("It will be removed from your review queue. Nothing was added to your calendar.")
            }
            .onDisappear {
                // A manual event closed without a save or draft is removed, not left in Review.
                let candidate = viewModel.candidate
                if !candidate.isDeleted {
                    ManualEventFactory.discardIfUnused(candidate, in: modelContext)
                }
            }
            .task {
                viewModel.findDuplicates(in: modelContext)
                await viewModel.prepareDestinations()
            }
        }
    }

    // MARK: - Layouts
    private var iPhoneSingleColumnContent: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: PDSpacing.lg) {
                    header
                    if !viewModel.isManualEntry {
                        sourceCard
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
                    formSection
                    actions(scrollProxy: proxy)
                        .padding(.horizontal)
                    if !viewModel.isManualEntry {
                        scanDetails
                            .id("scanDetails")
                    }
                }
            }
        }
    }

    private var iPadDualPaneContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header
                    .padding(.bottom, PDSpacing.md)

                HStack(alignment: .top, spacing: PDSpacing.lg) {
                    // LEFT COLUMN: Source Inspection & Document Preview
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: PDSpacing.md) {
                            iPadSourceInspector
                            scanDetails
                                .id("scanDetails")
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, PDSpacing.xl)
                    }
                    .frame(maxWidth: .infinity)

                    // RIGHT COLUMN: Extracted Fields, Resolving, & Action Pipeline
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: PDSpacing.md) {
                            if !viewModel.duplicateMatches.isEmpty && !duplicatesDismissed {
                                PossibleDuplicateBanner(
                                    matches: viewModel.duplicateMatches,
                                    onOpen: openSavedEvent,
                                    onKeepSeparate: { withAnimation { duplicatesDismissed = true } }
                                )
                            }
                            ForEach(viewModel.openQuestions) { question in
                                AmbiguityQuestionCard(question: question) { option in
                                    withAnimation { viewModel.answer(question, with: option) }
                                }
                            }
                            if viewModel.isAmbiguousDate && !viewModel.openQuestions.contains(where: { $0.field == .date }) {
                                ambiguityBanner
                                    .padding(.horizontal, 0)
                            }
                            formSection
                                .padding(.horizontal, 0)
                            actions(scrollProxy: proxy)
                                .padding(.horizontal, 0)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, PDSpacing.xl)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, PDSpacing.lg)
            }
        }
    }

    private var iPadSourceInspector: some View {
        EventReviewSourceInspector(
            viewModel: viewModel,
            viewport: $sourceViewport
        )
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: PDSpacing.md) {
            if viewModel.isManualEntry && !viewModel.isEditingSavedEvent {
                PDTopBar(title: "New event")
                PDScreenIntro(
                    eyebrow: "Enter manually",
                    title: "Add an event",
                    subtitle: "Your default calendar and reminders are already applied. Change anything before saving."
                )
            } else {
                PDTopBar(title: viewModel.isEditingSavedEvent ? "Edit event" : "Review event")
                PDScreenIntro(
                    eyebrow: viewModel.isEditingSavedEvent ? "Saved event" : "Verification stage",
                    title: viewModel.isEditingSavedEvent ? "Edit event" : "Review before saving",
                    subtitle: "Refine the timing, venue, and reminders before saving to your calendar."
                )
            }
        }
        .padding(.horizontal)
        .padding(.top, PDSpacing.sm)
    }

    private var confidenceBadge: some View {
        PDStatusBadge(
            text: "\(scorePercent)% · \(tier.label)",
            icon: tier.iconName,
            tone: tier == .high ? .success : .warning
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ambiguous Date Swap Prompt
    private var ambiguityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.pdWarning)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Ambiguous Date Detected")
                        .font(PDFont.bodyMD)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pdOnSurface)
                    if let frag = viewModel.ambiguousFragment {
                        Text("(\(frag))")
                            .font(PDFont.bodySM)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.pdWarning)
                    }
                }
                Text("Read as \(viewModel.startDate.formatted(.dateTime.month(.wide).day())). Swap if day and month are reversed.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Button("Keep this date") { viewModel.confirmDateOrder() }
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdSecondary)
                    .frame(minHeight: 44)
            }

            Spacer()

            Button {
                withAnimation { viewModel.swapMonthAndDay() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Switch")
                }
                .font(PDFont.bodySM)
                .fontWeight(.bold)
                .foregroundStyle(Color.pdSurface)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.pdWarning))
            }
            .frame(minHeight: 44)
            .accessibilityLabel("Swap month and day")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdWarning.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: PDRadius.card)
                        .stroke(Color.pdWarning.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Source Card
    private var sourceCard: some View {
        EventReviewSourceBanner(viewModel: viewModel, showOriginalDrawer: $showOriginalDrawer)
    }

    private var scanDetails: some View {
        VStack(spacing: PDSpacing.md) {
            if !viewModel.whyThisRows.isEmpty {
                WhyThisSection(rows: viewModel.whyThisRows, expandOnRequest: scanDetailsRequests)
            }
            if !rawLines.isEmpty { rawTextCard }
        }
        .padding(.horizontal)
    }

    // MARK: - Editable Form
    private var formSection: some View {
        VStack(spacing: 14) {
            // Order shared with Batch Review and Saved Event Detail: details, suggestions,
            // calendar & reminders, then what's on the flyer.
            PDSectionHeader(title: "Event details", trailing: "Tap any field to refine")
            EventReviewFieldsCard(viewModel: viewModel, onOpenURL: { openURL($0) })
            if !viewModel.visibleAlternatives.isEmpty {
                AlternativeInterpretationsCard(alternatives: viewModel.visibleAlternatives) { alternative in
                    withAnimation { viewModel.apply(alternative) }
                }
            }
            ReviewSuggestionsCard(
                viewModel: viewModel,
                isEntitledToReminderPlans: appState.isEntitled(to: .advancedReminderPlans),
                onUpgrade: { Task { await appState.present(.paywall(opening: .premium)) } }
            )
            PDSectionHeader(title: "Calendar & reminders")
            destinationCard
            if !viewModel.actions.isEmpty {
                EventActionsChecklist(
                    actions: viewModel.actions,
                    deadlineReminderDate: viewModel.deadlineReminderDate,
                    deadlineReminderEnabled: $viewModel.deadlineReminderEnabled,
                    isEntitledToDeadlineReminders: appState.isEntitled(to: .advancedReminderPlans),
                    onUpgrade: { Task { await appState.present(.paywall(opening: .premium)) } }
                )
            }
            #if DEBUG
            InterpretationDiagnosticsView(viewModel: viewModel)
            #endif
        }
        .padding(.horizontal)
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
                        .foregroundStyle(Color.pdSecondary)
                    Text("Extracted Source Text (Raw OCR)")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Spacer()
                    Image(systemName: showRawOcr ? "chevron.up" : "chevron.down")
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
            }

            if showRawOcr {
                VStack(alignment: .leading, spacing: 4) {
                    if let scan = viewModel.candidate.scannedAsset, scan.ocrConfidence > 0 {
                        Text("OCR confidence: \(Int((scan.ocrConfidence * 100).rounded()))%")
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    ForEach(Array(rawLines.enumerated()), id: \.offset) { index, line in
                        Text("> LINE \(index + 1): \(line)")
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.pdSecondary.opacity(0.85))
                .textSelection(.enabled)
                .padding(PDSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pdSurfaceLowest)
                .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
            }
        }
        .padding(PDSpacing.md)
        .pdGlassCard(cornerRadius: PDRadius.card)
    }

    // MARK: - Destination (Calendar, Reminders list, Alerts)
    private var destinationCard: some View {
        EventReviewDestinationCard(viewModel: viewModel, showScheduleEditor: $showScheduleEditor)
    }

    // MARK: - Actions
    private func actions(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 10) {
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(Color.pdOnPrimaryFixed)
                        Text("Saving...")
                    } else {
                        Text(viewModel.isEditingSavedEvent ? "Save changes" : "Save to Calendar")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
            }
            .buttonStyle(PDGradientButtonStyle())
            .disabled(viewModel.isSaving || isCommitting || viewModel.needsCalendarChoice || viewModel.needsTitle)

            if viewModel.needsTitle {
                Label("Add a title to save this event.", systemImage: "character.cursor.ibeam")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if viewModel.needsCalendarChoice {
                Label("Choose a calendar above to save this event.", systemImage: "calendar.badge.exclamationmark")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdWarning)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if !viewModel.whyThisRows.isEmpty || !viewModel.visibleAlternatives.isEmpty || !rawLines.isEmpty {
                Button {
                    showRawOcr = true
                    scanDetailsRequests += 1
                    withAnimation { scrollProxy.scrollTo("scanDetails", anchor: .top) }
                } label: {
                    Label("See scan details", systemImage: "info.circle")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            if !viewModel.isEditingSavedEvent {
                HStack(spacing: 12) {
                    Button {
                        let result = viewModel.saveDraft(modelContext: modelContext)
                        guard case .success = result else { return }
                        appState.showToast("Draft saved to Review Queue")
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bookmark")
                                .foregroundStyle(Color.pdSecondary)
                            Text("Save Draft")
                                .font(PDFont.labelMD)
                                .foregroundStyle(Color.pdOnSurface)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            Capsule()
                                .fill(Color.pdSurfaceHighest)
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
                                .foregroundStyle(Color.pdError)
                            Text(viewModel.candidate.savedEvent == nil ? "Discard" : "Close")
                                .font(PDFont.labelMD)
                                .foregroundStyle(Color.pdError)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                                Capsule()
                                    .fill(Color.pdError.opacity(0.12))
                        )
                    }
                }
            }
        }
        .disabled(isCommitting)
        .padding(.top, 4)
        .padding(.bottom, 24)
    }

    private func openSavedEvent(_ candidateID: String) {
        guard let match = SavedEventActions.candidate(id: candidateID, in: modelContext) else { return }
        Task { await appState.present(.savedEventDetail(match.toPencildEvent())) }
    }

    private func save() async {
        isCommitting = true
        lastSaveWasPartial = false
        defer { isCommitting = false }
        let wasUpdate = viewModel.isEditingSavedEvent
        let result = await viewModel.commitEvent(modelContext: modelContext)
        switch result {
        case .failure:
            if viewModel.calendarAccessDenied {
                await appState.present(.calendarPermissionDenied)
            }
            return
        case .partial:
            lastSaveWasPartial = true
            if viewModel.notificationsSkipped, await services.notifications.authorizationStatus() == .denied {
                appState.showToast(viewModel.errorMessage ?? "Event saved; local alerts are muted")
                viewModel.errorMessage = nil
                showNotificationRecovery = true
            }
            return
        case .success:
            break
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showSuccessToast = true }
        try? await Task.sleep(for: .seconds(1.1))
        appState.showToast(wasUpdate ? "Calendar event updated" : "Event saved to Calendar")
        await appState.present(.savedEventDetail(viewModel.candidate.toPencildEvent()))
    }

    private var successToast: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pdSuccess.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.pdSuccess)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Saved to Apple Calendar")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text("\(viewModel.candidate.savedEvent?.scheduledNotificationIds.count ?? 0) local alerts scheduled.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.pdSurfaceContainerHigh)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.pdSuccess.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 20)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}
