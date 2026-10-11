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
    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero

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
                if horizontalSizeClass == .regular {
                    iPadDualPaneContent
                } else {
                    iPhoneSingleColumnContent
                }

                if showSuccessToast { successToast }
            }
            .dsScreenBackground()
            .navigationBarHidden(true)
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
                    sourceCard
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
                    scanDetails
                        .id("scanDetails")
                    actions(scrollProxy: proxy)
                        .padding(.horizontal)
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
        VStack(spacing: PDSpacing.sm) {
            PDCard(highlighted: true) {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    HStack {
                        Label("Source Ingestion", systemImage: "document.viewfinder")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Spacer()
                        confidenceBadge
                    }

                    // Scalable Inspection Viewport
                    ZStack(alignment: .bottom) {
                        ZStack {
                            RoundedRectangle(cornerRadius: PDRadius.card)
                                .fill(Color.pdSurfaceLowest)
                                .frame(height: 480)

                            if let image = viewModel.sourceImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .scaleEffect(zoomScale)
                                    .offset(panOffset)
                                    .frame(maxHeight: 460)
                                    .clipped()
                                    .gesture(sourcePanGesture)
                                    .accessibilityLabel("Original scanned document")
                            } else {
                                PDScanSourceThumbnail(candidate: viewModel.candidate, width: nil, height: 460, contentMode: .fit)
                                    .scaleEffect(zoomScale)
                                    .offset(panOffset)
                                    .clipped()
                                    .gesture(sourcePanGesture)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))

                        // Floating Viewport Zoom Controls Toolbar
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(response: 0.25)) { zoomScale = max(0.8, zoomScale - 0.2) }
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.pdOnSurface)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Zoom out")

                            Text("\(Int(zoomScale * 100))%")
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minWidth: 44)

                            Button {
                                withAnimation(.spring(response: 0.25)) { zoomScale = min(2.5, zoomScale + 0.2) }
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.pdOnSurface)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Zoom in")

                            Divider()
                                .frame(height: 16)
                                .background(Color.pdOutlineVariant)

                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    zoomScale = 1.0
                                    panOffset = .zero
                                }
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Reset document view")
                        }
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.pdSurfaceContainerHigh.opacity(0.92))
                                .shadow(radius: 8)
                        )
                        .padding(.bottom, 12)
                    }

                    // Hardware & Privacy Guarantee Footer
                    HStack {
                        Label("Neural OCR On-Device", systemImage: "cpu")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdSecondary)
                        Spacer()
                        Label("Zero Cloud Leak", systemImage: "lock.shield.fill")
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdPrimary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var sourcePanGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard zoomScale > 1 else { return }
                panOffset = value.translation
            }
            .onEnded { _ in
                if zoomScale <= 1 { panOffset = .zero }
            }
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: PDSpacing.md) {
            PDTopBar(title: viewModel.isEditingSavedEvent ? "Edit event" : "Review event")
            HStack(spacing: PDSpacing.sm) {
                Text(viewModel.isEditingSavedEvent ? "Agenda" : "Review")
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                Text(viewModel.isEditingSavedEvent ? "Edit event" : "Verify details")
            }
            .font(PDFont.labelMD)
            .foregroundStyle(Color.pdOnSurfaceVariant)
            PDScreenIntro(
                eyebrow: viewModel.isEditingSavedEvent ? "Saved event" : "Verification stage",
                title: viewModel.isEditingSavedEvent ? "Edit event" : "Review before saving",
                subtitle: "Refine the timing, venue, and reminders before saving to your calendar."
            )
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
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.pdWarning.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.pdWarning.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }

    // MARK: - Source Card
    private var sourceCard: some View {
        PDCard(highlighted: true) {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top, spacing: 12) {
                    PDScanSourceThumbnail(candidate: viewModel.candidate, width: 68, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                    VStack(alignment: .leading, spacing: PDSpacing.xs) {
                        Text(viewModel.candidate.scannedAsset == nil ? "Manual entry" : "Source scan")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        confidenceBadge
                        if let scan = viewModel.candidate.scannedAsset {
                            Text("Scanned \(scan.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let route = viewModel.engineRoute {
                    EngineRouteBadge(route: route)
                }
                if viewModel.sourceImage != nil || viewModel.candidate.scannedAsset != nil {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showOriginalDrawer.toggle()
                        }
                    } label: {
                        PDChip(
                            text: showOriginalDrawer ? "Hide original" : "View original",
                            icon: showOriginalDrawer ? "eye.slash" : "eye",
                            selected: showOriginalDrawer
                        )
                    }
                    .buttonStyle(.plain)
                }
                if showOriginalDrawer {
                    Group {
                        if let image = viewModel.sourceImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 360)
                                .accessibilityLabel("Original scanned image")
                        } else {
                            PDScanSourceThumbnail(candidate: viewModel.candidate, width: nil, height: 360, contentMode: .fit)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal)
    }

    private var scanDetails: some View {
        VStack(spacing: PDSpacing.md) {
            if !viewModel.visibleAlternatives.isEmpty {
                AlternativeInterpretationsCard(alternatives: viewModel.visibleAlternatives) { alternative in
                    withAnimation { viewModel.apply(alternative) }
                }
            }
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
            PDSectionHeader(title: "Extracted fields", trailing: "Tap any field to refine")
            PDGroupedList {
                titleField.padding(PDSpacing.md)
                PDRowDivider()
                dateCard
                PDRowDivider()
                locationCard
                PDRowDivider()
                notesCard
            }
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
        }
        .padding(.horizontal)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("EVENT TITLE")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Spacer()
                if let source = viewModel.provenance(for: .title) {
                    ProvenanceChip(provenance: source.provenance, needsCheck: source.needsCheck)
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "textformat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pdPrimary)

                TextField("Enter event name...", text: $viewModel.title)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)

                if !viewModel.title.isEmpty {
                    Button {
                        viewModel.title = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Clear title")
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.tile)
                    .fill(Color.pdSurfaceLowest)
            )
        }
    }

    private var dateCard: some View {
        VStack(spacing: 12) {
            if let source = viewModel.provenance(for: .date) {
                HStack {
                    Text("WHEN")
                        .font(PDFont.labelSM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
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
                Divider().background(Color.pdSurfaceHighest)

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
                Label("Year wasn't on the flyer — Pencil'd picked the next upcoming one.", systemImage: "info.circle")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().background(Color.pdSurfaceHighest)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("All-Day Event")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Date only; no start or end time")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }

                Spacer()

                Toggle("All-Day Event", isOn: $viewModel.isAllDay)
                    .labelsHidden()
                    .toggleStyle(PDToggleStyle())
            }
        }
        .padding(PDSpacing.md)
    }

    @ViewBuilder
    private func dateRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            PDIconTile(systemName: icon, tint: .pdPrimary)

            Text(label)
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            Spacer()

            content()
                .tint(Color.pdPrimary)
                .colorScheme(.dark)
        }
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOCATION")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
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
                                .font(PDFont.bodySM)
                        }
                        .foregroundStyle(Color.pdInfo)
                        .frame(minHeight: 44)
                    }
                }
            }

            HStack(alignment: .top, spacing: 12) {
                PDIconTile(systemName: "mappin.and.ellipse", tint: .pdTertiary)

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Venue name", text: $viewModel.venueName)
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    TextField("Address", text: $viewModel.location)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }

            if !viewModel.rsvpUrl.isEmpty || viewModel.candidate.rsvpUrl != nil {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .foregroundStyle(Color.pdSecondary)
                    TextField("Tickets / RSVP link", text: $viewModel.rsvpUrl)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                .padding(.top, 4)
            }
        }
        .padding(PDSpacing.md)
    }

    private var mapsURL: URL? {
        let query = [viewModel.venueName, viewModel.location].filter { !$0.isEmpty }.joined(separator: ", ")
        guard !query.isEmpty, let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOTES & DETAILS")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)

            TextEditor(text: $viewModel.notes)
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurface)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 64)
                .padding(8)
                .overlay(alignment: .topLeading) {
                    if viewModel.notes.isEmpty {
                        Text("Add notes (door times, dress code, tickets)…")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(PDSpacing.md)
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
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.pdSurfaceLowest)
                .cornerRadius(12)
            }
        }
        .padding(14)
        .dsGlassCard(cornerRadius: PDRadius.card)
    }

    // MARK: - Destination (Calendar, Reminders list, Alerts)
    private var destinationCard: some View {
        VStack(spacing: 12) {
            HStack {
                PDIconTile(systemName: "calendar", tint: .pdPrimary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Saving To Calendar")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    if viewModel.availableCalendars.isEmpty {
                        Text("Default calendar (access requested on save)")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurface)
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
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurface)
                            .frame(minHeight: 44)
                        }
                    }
                }

                Spacer()
            }

            if !viewModel.availableReminderLists.isEmpty {
                HStack {
                    PDIconTile(systemName: "checklist", tint: .pdSecondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Reminders List")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        Menu {
                            ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                                Button(list.title) { viewModel.selectedReminderList = list }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.selectedReminderList?.title ?? "Choose list")
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                            }
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurface)
                            .frame(minHeight: 44)
                        }
                    }
                    Spacer()
                }
            }

            Button {
                showScheduleEditor = true
            } label: {
                HStack {
                    PDIconTile(systemName: "bell.badge.fill", tint: .pdSecondary)
                    Text(viewModel.selectedOffsets.isEmpty ? "No alerts" : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                        .lineLimit(1)
                    Spacer()
                    Text("\(viewModel.selectedOffsets.count) Alert\(viewModel.selectedOffsets.count == 1 ? "" : "s")")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.pdSurfaceHighest))
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Edit alerts, \(viewModel.selectedOffsets.count) selected")
        }
        .padding(14)
        .dsGlassCard(cornerRadius: PDRadius.card)
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
            .disabled(viewModel.isSaving || isCommitting)

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
                            RoundedRectangle(cornerRadius: 24)
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
                            RoundedRectangle(cornerRadius: 24)
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
