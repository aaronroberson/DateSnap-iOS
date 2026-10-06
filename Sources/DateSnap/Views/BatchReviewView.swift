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
    @EnvironmentObject private var appState: AppState
    @StateObject private var session: BatchReviewSession

    @State private var expandedIDs: Set<UUID> = []
    @State private var showDiscardConfirmFor: BatchEventItem? = nil
    @State private var showFailureAlert = false

    init(session: BatchReviewSession) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        ForEach(session.events) { event in
                            BatchEventCard(
                                event: event,
                                isExpanded: expandedIDs.contains(event.id),
                                onToggle: { toggle(event.id) },
                                onDiscard: { showDiscardConfirmFor = event }
                            )
                        }

                        if session.events.isEmpty {
                            emptyState
                        }

                        skippedCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 130)
                }

                if session.actionableCount > 0 || session.lastSummary != nil {
                    saveAllBar
                }
            }
            .dsScreenBackground()
            .navigationBarHidden(true)
            .task { await session.prepareDestinations() }
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
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.dsPrimary)
                Text("Batch Review")
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
            }

            Spacer()

            Text("\(session.events.count) event\(session.events.count == 1 ? "" : "s") · \(session.skipped.count) skipped")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .lineLimit(1)
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 38))
                .foregroundStyle(Color.dsSuccess)
            Text("Nothing left to review")
                .font(DSTypography.bodyStrong())
                .foregroundStyle(Color.dsForeground)
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
                    .font(DSTypography.overlineConfidence())
                    .foregroundStyle(Color.dsMutedForeground)
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
                                .fill(Color.dsCard)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.label)
                                .font(DSTypography.bodyCompact())
                                .foregroundStyle(Color.dsForeground)
                            Text(BatchReviewView.skipReason(for: item.stage))
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: skipIcon(for: item.stage))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(skipColor(for: item.stage))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(14)
            .dsGlassCard(cornerRadius: 20)
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
        case .failed: return Color.dsError
        case .alreadySaved: return Color.dsSuccess
        default: return Color.dsMutedForeground
        }
    }

    // MARK: Save-all bar

    private var saveAllBar: some View {
        VStack(spacing: 10) {
            if let summary = session.lastSummary {
                HStack(spacing: 6) {
                    Image(systemName: summary.isAllSaved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(summary.isAllSaved ? Color.dsSuccess : Color.dsWarning)
                    Text(summary.isAllSaved
                         ? "All \(summary.savedCount) event\(summary.savedCount == 1 ? "" : "s") saved"
                         : "\(summary.savedCount) of \(summary.savedCount + summary.failedMessages.count) saved — tap Save All to retry")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsForeground)
                }
            }

            Button {
                Task { await saveAll() }
            } label: {
                HStack(spacing: 8) {
                    if session.isSaving {
                        ProgressView().tint(Color.dsPrimaryForeground)
                        Text("Saving events…")
                    } else {
                        Image(systemName: "calendar.badge.plus")
                        Text("Save All (\(session.actionableCount))")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(session.isSaving || session.actionableCount == 0)
        }
        .padding(14)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(Color.dsBackground.opacity(0.95))
                .overlay(
                    Rectangle()
                        .fill(Color.dsPrimary.opacity(0.15))
                        .blur(radius: 24)
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func saveAll() async {
        let summary = await session.saveAll(modelContext: modelContext)
        if summary.failedMessages.isEmpty && summary.savedCount > 0 {
            appState.showToast("✓ Saved \(summary.savedCount) event\(summary.savedCount == 1 ? "" : "s") to Calendar & Reminders")
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
    @ObservedObject var event: BatchEventItem
    /// The card reads editable state through the review VM, so observe it directly too.
    @ObservedObject private var review: EventReviewViewModel
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDiscard: () -> Void

    init(event: BatchEventItem, isExpanded: Bool, onToggle: @escaping () -> Void, onDiscard: @escaping () -> Void) {
        _event = ObservedObject(wrappedValue: event)
        _review = ObservedObject(wrappedValue: event.review)
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onDiscard = onDiscard
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
        .dsGlassCard(cornerRadius: 20)
        .overlay(alignment: .topTrailing) {
            statusChip
                .padding(10)
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
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dsSuccess)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.dsSuccess.opacity(0.15)))
            case .failed:
                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.dsError)
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.dsError.opacity(0.15)))
            }
        }
    }

    private var header: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                screenshotThumb
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.review.title.isEmpty ? "Untitled Event" : event.review.title)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(event.review.selectedCalendar?.title ?? "Default calendar")
                            .lineLimit(1)
                    }
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.screenshotLabel), \(event.review.title), saving to \(event.review.selectedCalendar?.title ?? "default calendar")")
        .accessibilityHint(isExpanded ? "Collapse" : "Expand to edit details")
    }

    private var screenshotThumb: some View {
        Group {
            if let image = event.screenshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(Color.dsCard)
                    Image(systemName: "photo")
                        .foregroundStyle(Color.dsMutedForeground)
                }
            }
        }
        .frame(width: 56, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dsBorder, lineWidth: 1))
    }

    private var collapsedDestinations: some View {
        HStack(spacing: 12) {
            destinationSummary(
                icon: "checklist",
                tint: Color.dsInfo,
                text: event.review.selectedReminderList?.title ?? "No reminders list"
            )
            destinationSummary(
                icon: "bell.badge",
                tint: Color.dsSecondary,
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
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 12) {
            editableFields
            BatchDestinationsEditor(viewModel: event.review)
            actionRow
        }
    }

    private var editableFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            BatchTitledField(title: "EVENT TITLE", text: $review.title, placeholder: "Enter event name…", icon: "textformat", iconColor: .dsPrimary)
            BatchTitledField(title: "LOCATION", text: $review.location, placeholder: "Venue or address", icon: "mappin.and.ellipse", iconColor: .dsSecondary)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button(action: onDiscard) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.dsError)
                    Text("Discard")
                        .font(DSTypography.labelChip())
                        .foregroundStyle(Color.dsError)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsError.opacity(0.12)))
            }
            .disabled(!event.isActionable)

            Button {
                Task {
                    event.status = .saving
                    let result = await event.review.commitEvent(modelContext: modelContext)
                    switch result {
                    case .success, .partial:
                        event.status = .saved
                    case .failure(let error):
                        event.status = .failed(error.message)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if event.review.isSaving {
                        ProgressView().tint(Color.dsPrimaryForeground)
                    }
                    Text(event.review.isSaving ? "Saving…" : "Save")
                        .font(DSTypography.labelChip())
                        .foregroundStyle(Color.dsPrimary)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.dsPrimary.opacity(0.14)))
            }
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
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsMutedForeground)
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
                TextField(placeholder, text: $text)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.dsCard)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
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
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.dsMutedForeground)
                    Text("Default calendar (access requested on save)")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsSecondary)
                        .frame(width: 18)
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
                        .font(DSTypography.bodyCompact())
                        .foregroundStyle(Color.dsForeground)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !viewModel.availableReminderLists.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.dsInfo)
                        .frame(width: 18)
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
                        .font(DSTypography.bodyCompact())
                        .foregroundStyle(Color.dsForeground)
                        .frame(minHeight: 44)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                showScheduleEditor = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsSecondary)
                    Text(viewModel.selectedOffsets.isEmpty
                         ? "No alerts"
                         : viewModel.selectedOffsets.map(\.label).joined(separator: " · "))
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsForeground)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Edit alerts")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
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
