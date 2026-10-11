import SwiftUI
import UIKit
import EventKit
import SwiftData

// MARK: - Batch Review View
/// Reviews every event found across a multi-screenshot scan. Each event keeps its own
/// calendar, reminders list, and alert schedule; "Save All" commits each event to its
/// own destinations independently.
struct BatchReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var session: BatchReviewSession

    @State private var expandedIDs: Set<UUID> = []
    @State private var dismissedDuplicateWarnings: Set<UUID> = []
    @State private var showDiscardConfirmFor: BatchEventItem? = nil
    @State private var showFailureAlert = false
    @State private var pendingFailureAlert = false
    @State private var showNotificationRecovery = false

    init(session: BatchReviewSession) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        if horizontalSizeClass == .regular {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], alignment: .leading, spacing: 14) {
                                eventCards
                            }
                        } else {
                            eventCards
                        }

                        if session.events.isEmpty {
                            emptyState
                        }

                        skippedCard
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 1120 : .infinity)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
                    .padding(.bottom, 130)
                    .frame(maxWidth: .infinity)
                }

                if session.actionableCount > 0 || session.lastSummary != nil {
                    saveAllBar
                }
            }
            .dsScreenBackground()
            .navigationBarHidden(true)
            .task {
                await session.prepareDestinations()
                for event in session.events {
                    event.review.findDuplicates(in: modelContext)
                }
            }
            .sheet(isPresented: $showNotificationRecovery, onDismiss: {
                if pendingFailureAlert {
                    pendingFailureAlert = false
                    showFailureAlert = true
                }
            }) {
                NotificationPermissionDeniedView()
            }
            .alert("Some Events Did Not Save", isPresented: $showFailureAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failureMessage)
            }
            .confirmationDialog(
                "Discard this event?",
                isPresented: Binding(
                    get: { showDiscardConfirmFor != nil },
                    set: { if !$0 { showDiscardConfirmFor = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    if let event = showDiscardConfirmFor, session.discard(event, modelContext: modelContext) {
                        appState.showToast("Event discarded")
                    }
                }
            } message: {
                Text("It will be removed from your review queue. Nothing was added to your calendar.")
            }
        }
    }

    private var failureMessage: String {
        session.lastSummary?.failedMessages.joined(separator: "\n") ?? ""
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: PDSpacing.md) {
            PDTopBar(title: "Batch review")
            PDScreenIntro(
                eyebrow: "Verification stage",
                title: "Review your events",
                subtitle: "\(session.events.count) event\(session.events.count == 1 ? "" : "s") · \(session.skipped.count) skipped"
            )
            Text("Each event keeps its own calendar and reminder schedule.")
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .padding(.top, PDSpacing.sm)
    }

    private var eventCards: some View {
        ForEach(session.events) { event in
            BatchEventCard(
                event: event,
                isExpanded: expandedIDs.contains(event.id),
                duplicateWarningDismissed: dismissedDuplicateWarnings.contains(event.id),
                onDismissDuplicateWarning: { dismissedDuplicateWarnings.insert(event.id) },
                onToggle: { toggle(event.id) },
                onDiscard: { showDiscardConfirmFor = event },
                onNotificationsDenied: { showNotificationRecovery = true }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 38))
                .foregroundStyle(Color.pdSuccess)
            Text("Nothing left to review")
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdOnSurface)
            Button("Close") { dismiss() }
                .buttonStyle(DSSecondaryButtonStyle())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: Skipped screenshots

    @ViewBuilder
    private var skippedCard: some View {
        if !session.skipped.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("SKIPPED SCREENSHOTS")
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                ForEach(session.skipped) { item in
                    HStack(spacing: 10) {
                        if let image = item.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.pdSurfaceContainer)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label)
                                .font(PDFont.bodyMD)
                                .foregroundStyle(Color.pdOnSurface)
                            Text(BatchReviewView.skipReason(for: item.stage))
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: Self.skipIcon(for: item.stage))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Self.skipColor(for: item.stage))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .dsGlassCard(cornerRadius: PDRadius.card)
        }
    }

    private static func skipReason(for stage: BatchScanItem.Stage) -> String {
        switch stage {
        case .noDates: return "No event date found"
        case .alreadySaved(let count): return "Already saved (\(count) event\(count == 1 ? "" : "s"))"
        case .failed(let message): return message
        case .pending, .scanning: return "Not scanned"
        case .found: return "Saved below"
        }
    }

    private static func skipIcon(for stage: BatchScanItem.Stage) -> String {
        switch stage {
        case .failed: return "exclamationmark.triangle.fill"
        case .alreadySaved: return "checkmark.seal.fill"
        default: return "magnifyingglass"
        }
    }

    private static func skipColor(for stage: BatchScanItem.Stage) -> Color {
        switch stage {
        case .failed: return Color.pdError
        case .alreadySaved: return Color.pdSuccess
        default: return Color.pdOnSurfaceVariant
        }
    }

    // MARK: Save-all bar

    private var saveAllBar: some View {
        VStack(spacing: 10) {
            if let summary = session.lastSummary {
                HStack(spacing: 6) {
                    Image(systemName: summary.isAllSaved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(summary.isAllSaved ? Color.pdSuccess : Color.pdWarning)
                    Text(summary.isAllSaved
                         ? "All \(summary.savedCount) event\(summary.savedCount == 1 ? "" : "s") saved"
                         : "\(summary.savedCount) of \(summary.savedCount + summary.failedMessages.count) saved — tap Save All to retry")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                }
            }

            Button {
                Task { await saveAll() }
            } label: {
                HStack(spacing: 8) {
                    if session.isSaving {
                        ProgressView().tint(Color.pdOnPrimaryFixed)
                        Text("Saving events…")
                    } else {
                        Image(systemName: "calendar.badge.plus")
                        Text("Save All (\(session.actionableCount))")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(PDGradientButtonStyle())
            .disabled(session.isSaving || session.actionableCount == 0)
        }
        .padding(14)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.pdSurface.opacity(0.95))
                .overlay(
                    Rectangle()
                        .fill(Color.pdPrimary.opacity(0.15))
                        .blur(radius: 24)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func saveAll() async {
        let summary = await session.saveAll(modelContext: modelContext)
        if summary.failedMessages.isEmpty && summary.savedCount > 0 {
            appState.showToast("Saved \(summary.savedCount) event\(summary.savedCount == 1 ? "" : "s") to Calendar")
        }
        if session.events.contains(where: { $0.review.notificationsSkipped }),
           await services.notifications.authorizationStatus() == .denied {
            pendingFailureAlert = !summary.failedMessages.isEmpty
            showNotificationRecovery = true
        } else if !summary.failedMessages.isEmpty {
            showFailureAlert = true
        }
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
    }
}

// MARK: - Per-Event Card
private struct BatchEventCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @EnvironmentObject private var appState: AppState
    @ObservedObject var event: BatchEventItem
    /// The card reads editable state through the review VM, so observe it directly too.
    @ObservedObject private var review: EventReviewViewModel
    let isExpanded: Bool
    let duplicateWarningDismissed: Bool
    let onDismissDuplicateWarning: () -> Void
    let onToggle: () -> Void
    let onDiscard: () -> Void
    let onNotificationsDenied: () -> Void

    init(
        event: BatchEventItem,
        isExpanded: Bool,
        duplicateWarningDismissed: Bool,
        onDismissDuplicateWarning: @escaping () -> Void,
        onToggle: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onNotificationsDenied: @escaping () -> Void
    ) {
        _event = ObservedObject(wrappedValue: event)
        _review = ObservedObject(wrappedValue: event.review)
        self.isExpanded = isExpanded
        self.duplicateWarningDismissed = duplicateWarningDismissed
        self.onDismissDuplicateWarning = onDismissDuplicateWarning
        self.onToggle = onToggle
        self.onDiscard = onDiscard
        self.onNotificationsDenied = onNotificationsDenied
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if isExpanded {
                detail
            } else {
                collapsedDestinations
            }
        }
        .padding(14)
        .dsGlassCard(cornerRadius: PDRadius.card)

    }

    private var statusChip: some View {
        Group {
            switch event.status {
            case .pending:
                EmptyView()
            case .saving:
                ProgressView().controlSize(.small)
            case .saved:
                PDStatusBadge(
                    text: review.errorMessage == nil ? "Saved" : "Saved with issues",
                    icon: review.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tone: review.errorMessage == nil ? .success : .warning
                )
            case .failed:
                PDStatusBadge(text: "Failed", icon: "exclamationmark.triangle.fill", tone: .error)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    screenshotThumb
                    VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                        Text(review.title.isEmpty ? "Untitled event" : review.title)
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdOnSurface)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                        Label(review.selectedCalendar?.title ?? "Default calendar", systemImage: "calendar")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .lineLimit(1)
                        Text(review.startDate.formatted(date: .abbreviated, time: review.isAllDay ? .omitted : .shortened))
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                        statusChip
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(event.screenshotLabel), \(review.title), saving to \(review.selectedCalendar?.title ?? "default calendar")")
            .accessibilityHint(isExpanded ? "Collapse" : "Expand to edit details")
            if !review.duplicateMatches.isEmpty && !duplicateWarningDismissed {
                PossibleDuplicateBanner(
                    matches: review.duplicateMatches,
                    onOpen: { candidateID in
                        guard let candidate = SavedEventActions.candidate(id: candidateID, in: modelContext) else { return }
                        Task { await appState.present(.savedEventDetail(candidate.toPencildEvent())) }
                    },
                    onKeepSeparate: onDismissDuplicateWarning
                )
            }
        }
    }

    private var screenshotThumb: some View {
        Group {
            if let image = event.screenshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                PDScanSourceThumbnail(candidate: event.candidate, width: 56, height: 72)
            }
        }
        .frame(width: 56, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))

    }

    private var collapsedDestinations: some View {
        HStack(spacing: 12) {
            destinationSummary(
                icon: "checklist",
                tint: Color.pdInfo,
                text: event.review.selectedReminderList?.title ?? "No reminders list"
            )
            destinationSummary(
                icon: "bell.badge",
                tint: Color.pdSecondary,
                text: event.review.selectedOffsets.isEmpty
                    ? "No alerts"
                    : "\(event.review.selectedOffsets.count) alert\(event.review.selectedOffsets.count == 1 ? "" : "s")"
            )
        }
    }

    private func destinationSummary(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(text)
                .font(PDFont.bodySM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.screenshotLabel)
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
            PDStatusBadge(
                text: "\(Int((review.confidenceScore * 100).rounded()))% · \(review.confidenceTier.label)",
                icon: review.confidenceTier.iconName,
                tone: review.confidenceTier == .high ? .success : .warning
            )
            editableFields
            BatchDestinationsEditor(viewModel: event.review)
            if let issue = review.errorMessage {
                Label(issue, systemImage: "exclamationmark.triangle.fill")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdWarning)
            }
            actionRow
        }
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(title: "Extracted fields")
            PDGroupedList {
                BatchTitledField(title: "EVENT TITLE", text: $review.title, placeholder: "Enter event name…", icon: "textformat", iconColor: .pdPrimary)
                    .padding(PDSpacing.md)
                PDRowDivider()
                VStack(spacing: PDSpacing.sm) {
                    DatePicker(
                        review.isAllDay ? "Date" : "Starts",
                        selection: $review.startDate,
                        displayedComponents: review.isAllDay ? [.date] : [.date, .hourAndMinute]
                    )
                    .onChange(of: review.startDate) { previous, _ in review.startDateChanged(from: previous) }
                    if !review.isAllDay {
                        DatePicker("Ends", selection: $review.endDate, in: review.startDate..., displayedComponents: [.date, .hourAndMinute])
                    }
                    Toggle("All-day event", isOn: $review.isAllDay)
                        .toggleStyle(PDToggleStyle())
                }
                .font(PDFont.bodyMD)
                .tint(Color.pdPrimary)
                .padding(PDSpacing.md)
                PDRowDivider()
                BatchTitledField(title: "VENUE", text: $review.venueName, placeholder: "Venue name", icon: "mappin.and.ellipse", iconColor: .pdTertiary)
                    .padding(PDSpacing.md)
                PDRowDivider()
                BatchTitledField(title: "ADDRESS", text: $review.location, placeholder: "Address", icon: "map", iconColor: .pdTertiary)
                    .padding(PDSpacing.md)
                PDRowDivider()
                VStack(alignment: .leading, spacing: PDSpacing.xs) {
                    PDEyebrow(text: "Notes & details")
                    TextEditor(text: $review.notes)
                        .font(PDFont.bodyMD)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 64)
                        .accessibilityLabel("Notes and details")
                }
                .padding(PDSpacing.md)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: onDiscard) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.pdError)
                    Text("Discard")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdError)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.pdError.opacity(0.12)))
            }
            .disabled(!event.isActionable)

            Button {
                Task {
                    event.status = .saving
                    let result = await event.review.commitEvent(modelContext: modelContext)
                    switch result {
                    case .success, .partial:
                        event.status = .saved
                        if review.notificationsSkipped, await services.notifications.authorizationStatus() == .denied {
                            onNotificationsDenied()
                        }
                    case .failure(let error):
                        event.status = .failed(error.message)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if event.review.isSaving {
                        ProgressView().tint(Color.pdOnPrimaryFixed)
                    }
                    Text(event.review.isSaving ? "Saving…" : "Save")
                        .font(PDFont.labelMD)
                }
            }
            .buttonStyle(PDGradientButtonStyle())
            .disabled(event.review.isSaving || !event.isActionable)
        }
    }
}

// MARK: - Titled Field
struct BatchTitledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdOnSurfaceVariant)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                TextField(placeholder, text: $text)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.tile)
                    .fill(Color.pdSurfaceLowest)
            )
        }
    }
}

// MARK: - Destinations Editor (per-event calendar, reminders list, alerts)
struct BatchDestinationsEditor: View {
    @ObservedObject var viewModel: EventReviewViewModel
    @State private var showScheduleEditor = false

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.availableCalendars.isEmpty {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "calendar", tint: .pdPrimary)
                    Text("Default calendar (access requested on save)")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "calendar", tint: .pdPrimary)
                    Menu {
                        ForEach(viewModel.availableCalendars, id: \.calendarIdentifier) { calendar in
                            Button(calendar.title) { viewModel.selectedCalendar = calendar }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedCalendar?.title ?? "Choose calendar")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                        }
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !viewModel.availableReminderLists.isEmpty {
                HStack(spacing: 8) {
                    PDIconTile(systemName: "checklist", tint: .pdSecondary)
                    Menu {
                        ForEach(viewModel.availableReminderLists, id: \.calendarIdentifier) { list in
                            Button(list.title) { viewModel.selectedReminderList = list }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.selectedReminderList?.title ?? "Choose list")
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                        }
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                showScheduleEditor = true
            } label: {
                HStack(spacing: 6) {
                    PDIconTile(systemName: "bell.badge.fill", tint: .pdSecondary)
                    Text(viewModel.selectedOffsets.isEmpty
                         ? "No alerts"
                         : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurface)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Edit alerts")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceLowest)
        )
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
    }
}
