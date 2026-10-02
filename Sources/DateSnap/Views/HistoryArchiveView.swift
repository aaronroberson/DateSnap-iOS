import SwiftUI
import SwiftData

struct HistoryArchiveView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]
    
    @State private var selectedFilter: SavedEventStatus = .saved
    @State private var searchText: String = ""
    @State private var pendingDelete: SavedEvent? = nil
    @State private var smartFilter: SmartFilter? = nil

    /// Archive triage filters layered on the status chips.
    enum SmartFilter: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case rsvpDue = "RSVP Due"
        case repeating = "Repeats"
        case duplicates = "Possible Duplicates"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .upcoming: return "calendar"
            case .rsvpDue: return "envelope.badge"
            case .repeating: return "repeat"
            case .duplicates: return "square.on.square"
            }
        }
    }

    /// IDs of saved records that belong to a likely-duplicate cluster (Premium).
    private var duplicateIDs: Set<String> {
        guard appState.isEntitled(to: .duplicateClusters) else { return [] }
        let entries = savedEvents.compactMap { saved -> EventSimilarityService.Entry? in
            guard let candidate = saved.candidate else { return nil }
            return EventSimilarityService.Entry(id: saved.id, similarityKey: candidate.similarityKey, title: candidate.title,
                                                start: candidate.startDate, isSaved: saved.status == .saved)
        }
        return Set(EventSimilarityService.clusters(entries).flatMap { $0.map(\.id) })
    }

    private func matches(_ filter: SmartFilter, _ saved: SavedEvent, candidate: EventCandidate, duplicates: Set<String>) -> Bool {
        let now = Date()
        switch filter {
        case .upcoming: return candidate.startDate >= now
        case .rsvpDue: return (candidate.rsvpDeadline.map { $0 >= Calendar.current.startOfDay(for: now) }) ?? false
        case .repeating: return candidate.recurrenceRaw != nil || candidate.interpretation?.stored?.understanding.recurrence != nil
        case .duplicates: return duplicates.contains(saved.id)
        }
    }
    
    private var actions: SavedEventActions {
        SavedEventActions(services: services, modelContext: modelContext)
    }

    private func count(_ status: SavedEventStatus) -> Int {
        savedEvents.filter { $0.status == status }.count
    }

    /// Records in the selected status, matching the search across title, venue, address, notes and date.
    private var filteredEvents: [SavedEvent] {
        savedEvents.filter { saved in
            guard saved.status == selectedFilter, let candidate = saved.candidate else { return false }
            if let smartFilter, !matches(smartFilter, saved, candidate: candidate, duplicates: smartFilter == .duplicates ? duplicateIDs : []) {
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Area
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TEMPORAL LOG • ON-DEVICE")
                                .font(DSTypography.overlineConfidence())
                                .foregroundStyle(Color.dsPrimary)
                            
                            Text("History & Archive")
                                .font(DSTypography.displayTitle())
                                .foregroundStyle(Color.dsForeground)
                        }
                        
                        Spacer()
                        
                        Button {
                            appState.selectedTab = .home
                        } label: {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color.dsPrimary)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color.dsCardElevated))
                        }
                        .accessibilityLabel("Scan a new screenshot")
                    }
                    
                    Text("All synced events, past scans, and triage records.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                    
                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.dsMutedForeground)
                        
                        TextField("Search events, venues, dates...", text: $searchText)
                            .font(DSTypography.bodyCompact())
                            .foregroundStyle(Color.dsForeground)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.dsMutedForeground)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.dsCard)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
                    )
                    .padding(.top, 6)
                    
                    // Filter Chips Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            filterChip(status: .saved, count: count(.saved))
                            filterChip(status: .draft, count: count(.draft))
                            filterChip(status: .archived, count: count(.archived))
                        }
                        .padding(.vertical, 8)
                    }

                    // Smart triage filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SmartFilter.allCases) { filter in
                                smartFilterChip(filter)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)
                
                // Events List or Empty State
                List {
                    Group {
                        HStack {
                            Text(selectedFilter == .saved ? "Upcoming First" : selectedFilter.eventStatus.rawValue)
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Spacer()
                            Text("\(filteredEvents.count) Events")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        .padding(.horizontal)
                        .padding(.top, 6)
                        
                        if filteredEvents.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .padding(.top, 36)
                                Text(searchText.isEmpty ? "No \(selectedFilter.eventStatus.rawValue.lowercased()) events yet" : "No matches for “\(searchText)”")
                                    .font(DSTypography.bodyStrong())
                                    .foregroundStyle(Color.dsForeground)
                                Text("Screenshots scanned and parsed will appear in this timeline.")
                                    .font(DSTypography.caption())
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal)
                        } else {
                            ForEach(filteredEvents) { saved in
                                eventCard(saved: saved)
                            }
                        }
                        Color.clear.frame(height: 90)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: 0, bottom: 7, trailing: 0))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
            .dsScreenBackground()
            .confirmationDialog(
                "Delete this event?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { saved in
                Button("Delete from DateSnap Only", role: .destructive) {
                    reportMutation(actions.delete(saved, removeFromCalendar: false), success: "Removed from DateSnap history")
                }
                if saved.externalCalendarEventId != nil {
                    Button("Delete from Calendar & Reminders Too", role: .destructive) {
                        reportMutation(actions.delete(saved, removeFromCalendar: true), success: "Deleted event and linked reminders")
                    }
                }
            } message: { _ in
                Text("Pending DateSnap alerts for this event will be cancelled.")
            }
        }
    }
    
    private func reportMutation(_ result: MutationResult, success: String) {
        switch result {
        case .success:
            appState.showToast(success)
        case .partial(let issues):
            appState.showToast("Some linked items could not be updated: \(issues.joined(separator: "; "))")
        case .failure(let error):
            appState.showToast("Couldn't complete the action: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func smartFilterChip(_ filter: SmartFilter) -> some View {
        let isSelected = smartFilter == filter
        let locked = filter == .duplicates && !appState.isEntitled(to: .duplicateClusters)
        Button {
            if locked {
                appState.activeModal = .premiumPaywall
            } else {
                smartFilter = isSelected ? nil : filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: locked ? "lock.fill" : filter.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(filter.rawValue)
                    .font(DSTypography.caption())
            }
            .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsMutedForeground)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? Color.dsPrimary.opacity(0.14) : Color.clear)
                    .overlay(Capsule().stroke(isSelected ? Color.dsPrimary : Color.dsBorder, lineWidth: 1))
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(locked ? PremiumFeature.duplicateClusters.upgradeReason : "Filters the history list")
    }

    @ViewBuilder
    private func filterChip(status: SavedEventStatus, count: Int) -> some View {
        let isSelected = selectedFilter == status
        Button {
            selectedFilter = status
        } label: {
            HStack(spacing: 6) {
                Text(status.eventStatus.rawValue)
                    .font(DSTypography.labelChip())
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isSelected ? Color.dsPrimary.opacity(0.3) : Color.white.opacity(0.1))
                    )
            }
            .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsMutedForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.dsSecondary.opacity(0.2) : Color.dsCard)
                    .overlay(
                        Capsule().stroke(isSelected ? Color.dsPrimary : Color.dsBorder, lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private func eventCard(saved: SavedEvent) -> some View {
        let event = saved.candidate?.toDateSnapEvent()
        if let event {
            Button {
                if saved.status == .draft {
                    appState.activeModal = .eventReviewEdit(event)
                } else {
                    appState.activeModal = .savedEventDetail(event)
                }
            } label: {
                HStack(spacing: 14) {
                    DSDateBadge(month: event.month, day: event.day, isSelected: saved.status == .saved)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(event.title)
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.dsMutedForeground)
                            Text("\(event.locationName) • \(event.timeWindow)")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .lineLimit(1)
                        }
                        
                        HStack(spacing: 8) {
                            statusBadge(for: saved)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.dsSecondary)
                                Text(event.targetCalendar)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.dsMutedForeground)
                                    .lineLimit(1)
                            }
                            
                            if !saved.alertOffsets.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.dsAccent)
                                    Text("\(saved.alertOffsets.count) Alert\(saved.alertOffsets.count == 1 ? "" : "s")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.dsMutedForeground)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .dsGlassCard(cornerRadius: 18)
                .padding(.horizontal)
            }
            .contextMenu { triageMenu(for: saved) }
            .swipeActions { triageMenu(for: saved) }
            .accessibilityAction(named: saved.status == .archived ? "Restore" : "Archive") {
                let status = saved.status == .archived ? SavedEventStatus.saved : .archived
                reportMutation(actions.setStatus(status, for: saved), success: status == .saved ? "Event restored" : "Event archived")
            }
            .accessibilityAction(named: "Delete") { pendingDelete = saved }
        }
    }

    @ViewBuilder
    private func statusBadge(for saved: SavedEvent) -> some View {
        switch saved.status {
        case .saved:
            HStack(spacing: 4) {
                Image(systemName: saved.externalCalendarEventId != nil ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(.system(size: 10))
                Text(saved.externalCalendarEventId != nil ? "In Calendar" : "Not in Calendar")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(saved.externalCalendarEventId != nil ? Color.dsSuccess : Color.dsWarning)
        case .draft:
            HStack(spacing: 4) {
                Image(systemName: "bookmark.fill").font(.system(size: 10))
                Text("Draft").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.dsWarning)
        case .archived:
            HStack(spacing: 4) {
                Image(systemName: "archivebox.fill").font(.system(size: 10))
                Text("Archived").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Color.dsMutedForeground)
        }
    }

    /// Triage actions shared by the context menu and swipe actions.
    @ViewBuilder
    private func triageMenu(for saved: SavedEvent) -> some View {
        if saved.status == .archived {
            Button {
                let status: SavedEventStatus = saved.externalCalendarEventId != nil ? .saved : .draft
                reportMutation(actions.setStatus(status, for: saved), success: "Event restored")
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
        if saved.status == .saved, let event = saved.candidate?.toDateSnapEvent() {
            Button {
                appState.activeModal = .eventReviewEdit(event)
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
}
