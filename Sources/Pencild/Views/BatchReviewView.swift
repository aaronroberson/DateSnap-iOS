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
    /// A possible-duplicate saved event opened from a card. Shown from this sheet because the
    /// root can present only one sheet and leaving would discard the batch's unsaved edits.
    @State private var openedDuplicate: PencildEvent? = nil
    @State private var showPlusPaywall = false
    @State private var showPremiumPaywall = false

    init(session: BatchReviewSession) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: PDSpacing.lg) {
                        header

                        if session.events.isEmpty {
                            emptyState
                        } else {
                            eventsSection
                        }

                        skippedSection
                    }
                    .frame(maxWidth: Self.contentMaxWidth(for: horizontalSizeClass))
                    .padding(.horizontal, Self.horizontalPadding(for: horizontalSizeClass))
                    .padding(.bottom, 130)
                    .frame(maxWidth: .infinity)
                }

                if session.actionableCount > 0 || session.lastSummary != nil {
                    saveAllBar
                }
            }
            .pdScreenBackground()
            .navigationBarHidden(true)
            .task {
                await session.prepareDestinations()
                for event in session.events {
                    event.review.findDuplicates(in: modelContext)
                }
            }
            .sheet(item: $openedDuplicate) { event in
                SavedEventDetailView(event: event)
            }
            .sheet(isPresented: $showPlusPaywall) {
                PlusPaywallView()
            }
            .sheet(isPresented: $showPremiumPaywall) {
                PremiumPaywallView()
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
                subtitle: "Each event keeps its own calendar and reminder schedule. Nothing is saved until you confirm."
            )
        }
        .padding(.top, PDSpacing.sm)
    }

    static func contentMaxWidth(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 1120 : .infinity
    }

    static func horizontalPadding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 28 : PDSpacing.md
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            PDSectionHeader(
                title: "Detected events",
                trailing: "\(session.events.count) event\(session.events.count == 1 ? "" : "s")"
            )
            if horizontalSizeClass == .regular {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: PDSpacing.md), GridItem(.flexible(), spacing: PDSpacing.md)],
                    alignment: .leading,
                    spacing: PDSpacing.md
                ) {
                    eventCards
                }
            } else {
                VStack(spacing: PDSpacing.md) { eventCards }
            }
        }
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
                onNotificationsDenied: { showNotificationRecovery = true },
                onOpenDuplicate: { openedDuplicate = $0 },
                onUpgradeToPremium: { showPremiumPaywall = true }
            )
        }
    }

    private var emptyState: some View {
        PDCard {
            VStack(spacing: PDSpacing.sm) {
                PDIconTile(systemName: "checkmark.seal", tint: .pdSuccess)
                Text("Nothing left to review")
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
                Button("Close") { dismiss() }
                    .buttonStyle(PDSecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Skipped screenshots

    @ViewBuilder
    private var skippedSection: some View {
        if !session.skipped.isEmpty {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                PDSectionHeader(title: "Skipped screenshots", trailing: "\(session.skipped.count)")
                if session.hitScanLimit {
                    Button { showPlusPaywall = true } label: {
                        HStack(spacing: PDSpacing.sm) {
                            Image(systemName: "sparkle").foregroundStyle(Color.pdPrimary)
                            Text(PlanLimits.scanLimitMessage)
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurface)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                        .padding(PDSpacing.md)
                        .frame(minHeight: 44)
                        .background(Color.pdSurfaceContainer.opacity(0.85), in: RoundedRectangle(cornerRadius: PDRadius.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens upgrade options")
                }
                PDGroupedList {
                    ForEach(Array(session.skipped.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { PDRowDivider() }
                        skippedRow(item)
                    }
                }
            }
        }
    }

    private func skippedRow(_ item: BatchScanItem) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = item.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    PDIconTile(systemName: "photo", tint: .pdOnSurfaceVariant)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.label)
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text(BatchReviewView.skipReason(for: item.stage))
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: Self.skipIcon(for: item.stage))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Self.skipColor(for: item.stage))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, PDSpacing.md)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
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
        case .alreadySaved: return "calendar.badge.checkmark"
        default: return "calendar.badge.exclamationmark"
        }
    }

    private static func skipColor(for stage: BatchScanItem.Stage) -> Color {
        switch stage {
        case .failed: return Color.pdError
        case .alreadySaved: return Color.pdSuccess
        default: return Color.pdWarning
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
        .frame(maxWidth: horizontalSizeClass == .regular ? 560 : .infinity)
        .padding(.horizontal, Self.horizontalPadding(for: horizontalSizeClass))
        .padding(.top, PDSpacing.md)
        .padding(.bottom, PDSpacing.sm)
        .frame(maxWidth: .infinity)
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
    let onOpenDuplicate: (PencildEvent) -> Void
    let onUpgradeToPremium: () -> Void

    init(
        event: BatchEventItem,
        isExpanded: Bool,
        duplicateWarningDismissed: Bool,
        onDismissDuplicateWarning: @escaping () -> Void,
        onToggle: @escaping () -> Void,
        onDiscard: @escaping () -> Void,
        onNotificationsDenied: @escaping () -> Void,
        onOpenDuplicate: @escaping (PencildEvent) -> Void,
        onUpgradeToPremium: @escaping () -> Void
    ) {
        _event = ObservedObject(wrappedValue: event)
        _review = ObservedObject(wrappedValue: event.review)
        self.isExpanded = isExpanded
        self.duplicateWarningDismissed = duplicateWarningDismissed
        self.onDismissDuplicateWarning = onDismissDuplicateWarning
        self.onToggle = onToggle
        self.onDiscard = onDiscard
        self.onNotificationsDenied = onNotificationsDenied
        self.onOpenDuplicate = onOpenDuplicate
        self.onUpgradeToPremium = onUpgradeToPremium
    }

    var body: some View {
        PDCard {
            VStack(alignment: .leading, spacing: 12) {
                header
                if isExpanded {
                    detail
                } else {
                    collapsedDestinations
                }
            }
        }
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
                        onOpenDuplicate(candidate.toPencildEvent())
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
        .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
        .accessibilityHidden(true)
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
            ReviewSuggestionsCard(
                viewModel: review,
                isEntitledToReminderPlans: appState.isEntitled(to: .advancedReminderPlans),
                onUpgrade: onUpgradeToPremium
            )
            PDSectionHeader(title: "Calendar & reminders")
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
            PDSectionHeader(title: "Event details")
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
                .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdError.opacity(0.12)))
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

