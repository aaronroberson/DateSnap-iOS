import SwiftUI
import SwiftData

struct HistoryArchiveView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]
    
    @State private var selectedFilter: SavedEventStatus = .saved
    @State private var searchText: String = ""
    @State private var pendingDelete: SavedEvent? = nil
    @State private var smartFilter: EventSmartFilter? = nil

    private var actions: SavedEventActions {
        SavedEventActions(services: services, modelContext: modelContext)
    }

    private func count(_ status: SavedEventStatus) -> Int {
        savedEvents.filter { $0.status == status }.count
    }

    /// Records in the selected status, matching the search across title, venue, address, notes and date.
    private var filteredEvents: [SavedEvent] {
        let duplicates = smartFilter == .duplicates
            ? EventSmartFilter.duplicateIDs(in: savedEvents, services: services)
            : []
        return savedEvents.filter { saved in
            guard saved.status == selectedFilter, let candidate = saved.candidate else { return false }
            if let smartFilter, !smartFilter.matches(saved, candidate: candidate, duplicates: duplicates) {
                return false
            }
            guard !searchText.isEmpty else { return true }
            let dateText = candidate.startDate.formatted(date: .complete, time: .omitted)
            return [candidate.title, candidate.venueName ?? "", candidate.location ?? "", candidate.notes, dateText, saved.targetCalendar]
                .contains { $0.localizedCaseInsensitiveContains(searchText) }
        }
        .sorted { lhs, rhs in
            // Upcoming events first (soonest on top), then past events (most recent first).
            let now = Date()
            let l = lhs.candidate?.startDate ?? .distantPast
            let r = rhs.candidate?.startDate ?? .distantPast
            switch (l >= now, r >= now) {
            case (true, true): return l < r
            case (false, false): return l > r
            default: return l >= now
            }
        }
    }
    
    /// Group the real filtered records by their event month, retaining upcoming-first order.
    private var monthGroups: [(month: Date, events: [SavedEvent])] {
        var groups: [(month: Date, events: [SavedEvent])] = []
        for saved in filteredEvents {
            guard let candidate = saved.candidate,
                  let month = Calendar.current.dateInterval(of: .month, for: candidate.startDate)?.start else { continue }
            if let index = groups.firstIndex(where: { $0.month == month }) {
                groups[index].events.append(saved)
            } else {
                groups.append((month, [saved]))
            }
        }
        return groups
    }

    /// Only persisted scans attached to history records are counted; no invented storage sizes.
    private var retainedScanCount: Int {
        Set(savedEvents.compactMap { $0.candidate?.scannedAsset?.id }).count
    }

    var body: some View {
        Group {
            VStack(spacing: 0) {
                PDTopBar(title: "Repository & Logs")
                    .frame(maxWidth: horizontalSizeClass == .regular ? 1080 : .infinity)
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    HStack(alignment: .top, spacing: PDSpacing.md) {
                        PDScreenIntro(eyebrow: "ON YOUR DEVICE", title: "History & Archive", subtitle: "Your saved events, drafts, and archived scans.")
                        Spacer(minLength: 0)
                        Button { appState.selectedTab = .home } label: {
                            PDIconTile(systemName: "camera.viewfinder", size: .large)
                        }
                        .accessibilityLabel("Scan a new screenshot")
                    }
                    EventSearchFilterBar(
                        searchText: $searchText,
                        status: Binding(get: { selectedFilter }, set: { if let status = $0 { selectedFilter = status } }),
                        smartFilter: $smartFilter,
                        counts: Dictionary(uniqueKeysWithValues: SavedEventStatus.allCases.map { ($0, count($0)) }),
                        idPrefix: "history",
                        palette: .pencild
                    )
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 1080 : .infinity)
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
                .padding(.top, 10)
                .padding(.bottom, 8)

                List {
                    Group {
                        PDSectionHeader(title: selectedFilter == .saved ? "Upcoming first" : selectedFilter.eventStatus.rawValue,
                                        trailing: "\(filteredEvents.count) event\(filteredEvents.count == 1 ? "" : "s")")
                            .padding(.horizontal, PDSpacing.md)
                        if filteredEvents.isEmpty {
                            emptyState
                        } else {
                            ForEach(monthGroups, id: \.month) { group in
                                Text(group.month.formatted(.dateTime.month(.wide).year()))
                                    .font(PDFont.labelLG).foregroundStyle(Color.pdPrimary)
                                    .padding(.horizontal, PDSpacing.md).padding(.top, PDSpacing.sm)
                                ForEach(group.events) { saved in eventCard(saved: saved) }
                            }
                        }
                        localStorage
                        Color.clear.frame(height: 90)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .frame(maxWidth: horizontalSizeClass == .regular ? 1080 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .pdScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .confirmationDialog(
                "Delete this event?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { saved in
                Button("Delete from Pencil’d Only", role: .destructive) {
                    reportMutation(actions.delete(saved, removeFromCalendar: false), success: "Removed from Pencil’d history")
                }
                if saved.externalCalendarEventId != nil || !saved.externalReminderIds.isEmpty || saved.deadlineReminderId != nil {
                    Button("Delete from Calendar & Reminders Too", role: .destructive) {
                        reportMutation(actions.delete(saved, removeFromCalendar: true), success: "Deleted event")
                    }
                }
            } message: { _ in
                Text("Pending Pencil’d alerts for this event will be cancelled.")
            }
        }
    }

    private var emptyState: some View {
        PDCard {
            VStack(spacing: PDSpacing.md) {
                PDIconTile(systemName: "tray", tint: .pdSecondary, size: .large)
                Text(searchText.isEmpty ? "No \(selectedFilter.eventStatus.rawValue.lowercased()) events match these filters" : "No matches for “\(searchText)”")
                    .font(PDFont.headlineSM).foregroundStyle(Color.pdOnSurface)
                Text("Try a different filter or scan a screenshot to add an event.")
                    .font(PDFont.bodyMD).foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button { appState.selectedTab = .home } label: {
                    Label("Scan a screenshot", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PDPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, PDSpacing.md)
    }

    private var localStorage: some View {
        PDCard {
            HStack(alignment: .top, spacing: PDSpacing.sm) {
                PDIconTile(systemName: "internaldrive", tint: .pdSecondary)
                VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                    Text("Local scan history").font(PDFont.labelLG).foregroundStyle(Color.pdOnSurface)
                    Text("\(retainedScanCount) scan\(retainedScanCount == 1 ? "" : "s") linked to \(savedEvents.count) event\(savedEvents.count == 1 ? "" : "s")")
                        .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                    Text("Deleting a Pencil’d record removes it from this history. Original images remain in Photos when available.")
                        .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, PDSpacing.md)
    }

    @ViewBuilder
    private func eventCard(saved: SavedEvent) -> some View {
        if let candidate = saved.candidate {
            let event = candidate.toPencildEvent()
            PDCard {
                VStack(alignment: .leading, spacing: PDSpacing.sm) {
                    Button {
                        Task { await appState.present(saved.status == .draft ? .eventReviewEdit(event) : .savedEventDetail(event)) }
                    } label: {
                        HStack(alignment: .top, spacing: PDSpacing.md) {
                            PDScanSourceThumbnail(candidate: candidate)
                            VStack(alignment: .leading, spacing: PDSpacing.xxs) {
                                Text(event.title).font(PDFont.headlineSM).foregroundStyle(Color.pdOnSurface)
                                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                Text(candidate.startDate.formatted(date: .abbreviated, time: candidate.isAllDay ? .omitted : .shortened))
                                    .font(PDFont.bodySM).foregroundStyle(Color.pdPrimary)
                                Label(event.locationName, systemImage: "mappin.and.ellipse")
                                    .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant).lineLimit(1)
                                PDStatusBadge(text: "\(event.confidenceScore)% · \(event.confidenceLabel)", icon: "sparkles", tone: event.confidenceScore >= 80 ? .success : .warning)
                            }
                            Image(systemName: "chevron.right").font(PDFont.labelMD).foregroundStyle(Color.pdOutline)
                                .padding(.top, PDSpacing.sm)
                        }
                        .frame(minHeight: 76)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: PDSpacing.sm) {
                        statusBadge(for: saved)
                        if !saved.alertOffsets.isEmpty {
                            Label("\(saved.alertOffsets.count)", systemImage: "bell")
                                .font(PDFont.labelMD).foregroundStyle(Color.pdSecondary)
                                .accessibilityLabel("\(saved.alertOffsets.count) configured alerts")
                        }
                        Spacer(minLength: 0)
                        Button { toggleArchive(saved) } label: {
                            Label(saved.status == .archived ? "Restore" : "Archive",
                                  systemImage: saved.status == .archived ? "arrow.uturn.backward" : "archivebox")
                                .font(PDFont.labelMD).foregroundStyle(Color.pdSecondary).frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    }
                    if saved.externalCalendarEventId != nil {
                        Label(saved.targetCalendar, systemImage: "calendar")
                            .font(PDFont.bodySM).foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                }
            }
            .padding(.horizontal, PDSpacing.md)
            .contextMenu { triageMenu(for: saved) }
            .swipeActions { triageMenu(for: saved) }
            .accessibilityAction(named: saved.status == .archived ? "Restore" : "Archive") { toggleArchive(saved) }
            .accessibilityAction(named: "Delete") { pendingDelete = saved }
        }
    }

    @ViewBuilder
    private func statusBadge(for saved: SavedEvent) -> some View {
        switch saved.status {
        case .saved:
            PDStatusBadge(text: saved.externalCalendarEventId != nil ? "Saved to Calendar" : "Not in Calendar",
                          icon: saved.externalCalendarEventId != nil ? "checkmark.circle" : "exclamationmark.circle",
                          tone: saved.externalCalendarEventId != nil ? .success : .warning)
        case .draft: PDStatusBadge(text: "Draft", icon: "bookmark", tone: .warning)
        case .archived: PDStatusBadge(text: "Archived", icon: "archivebox")
        }
    }

    private func toggleArchive(_ saved: SavedEvent) {
        let restoring = saved.status == .archived
        let destination: SavedEventStatus = restoring ? (saved.externalCalendarEventId != nil ? .saved : .draft) : .archived
        reportMutation(actions.setStatus(destination, for: saved), success: restoring ? "Event restored" : "Event archived")
    }

    /// Triage actions shared by the context menu and swipe actions.
    @ViewBuilder
    private func triageMenu(for saved: SavedEvent) -> some View {
        if saved.status == .archived {
            Button {
                let result = actions.setStatus(saved.externalCalendarEventId != nil ? .saved : .draft, for: saved)
                reportMutation(result, success: "Event restored")
            } label: {
                Label("Restore", systemImage: "arrow.uturn.backward")
            }
        } else {
            Button {
                reportMutation(actions.setStatus(.archived, for: saved), success: "Event archived")
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
        }
        if saved.status == .saved, let event = saved.candidate?.toPencildEvent() {
            Button {
                Task { await appState.present(.eventReviewEdit(event)) }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        Button(role: .destructive) {
            pendingDelete = saved
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func reportMutation(_ result: MutationResult, success: String) {
        switch result {
        case .success:
            appState.showToast(success)
        case .partial(let issues):
            appState.showToast("Completed with issues: \(issues.joined(separator: "; "))")
        case .failure(let error):
            appState.showToast(error.localizedDescription)
        }
    }
}
