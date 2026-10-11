import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]

    @State private var searchText = ""
    @State private var selectedFilter: AgendaDateFilter = .upcoming
    @State private var selectedStatus: SavedEventStatus = .saved
    @State private var smartFilter: EventSmartFilter? = nil

    private var agendaEvents: [SavedEvent] {
        let duplicates = smartFilter == .duplicates
            ? EventSmartFilter.duplicateIDs(in: savedEvents, services: services)
            : []
        return savedEvents
            .filter { $0.status == selectedStatus && $0.candidate != nil }
            .filter { saved in
                guard let candidate = saved.candidate else { return false }
                if let smartFilter, !smartFilter.matches(saved, candidate: candidate, duplicates: duplicates) { return false }
                return selectedFilter.includes(candidate.startDate, relativeTo: Date()) && matchesSearch(saved, candidate: candidate)
            }
            .sorted { ($0.candidate?.startDate ?? .distantFuture) < ($1.candidate?.startDate ?? .distantFuture) }
    }

    private var statusCounts: [SavedEventStatus: Int] {
        Dictionary(uniqueKeysWithValues: SavedEventStatus.allCases.map { status in
            (status, savedEvents.filter { $0.status == status && $0.candidate != nil }.count)
        })
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || smartFilter != nil
    }

    private var todayEvents: [SavedEvent] {
        agendaEvents.filter { saved in
            guard let date = saved.candidate?.startDate else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    private var upcomingEvents: [SavedEvent] {
        agendaEvents.filter { saved in
            guard let date = saved.candidate?.startDate else { return false }
            return !Calendar.current.isDateInToday(date) && date >= Calendar.current.startOfDay(for: Date())
        }
    }

    private var pastEvents: [SavedEvent] {
        agendaEvents.filter { saved in
            guard let date = saved.candidate?.startDate else { return false }
            return date < Calendar.current.startOfDay(for: Date())
        }
    }

    private func groupedDays(_ events: [SavedEvent]) -> [(date: Date, events: [SavedEvent])] {
        let groups = Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.candidate!.startDate) }
        return groups.keys.sorted().map { (date: $0, events: groups[$0] ?? []) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                EventSearchFilterBar(
                    searchText: $searchText,
                    status: $selectedStatus,
                    smartFilter: $smartFilter,
                    counts: statusCounts,
                    excludedSmartFilters: [.upcoming],
                    idPrefix: "agenda",
                    palette: .pencild
                )
                dateFilters

                if agendaEvents.isEmpty {
                    emptyState
                } else {
                    if !todayEvents.isEmpty {
                        eventSection("Today\u{2019}s events", events: todayEvents, highlighted: true)
                    }
                    if !upcomingEvents.isEmpty {
                        ForEach(groupedDays(upcomingEvents), id: \.date) { day in
                            eventSection(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), events: day.events, highlighted: false)
                        }
                    }
                    if !pastEvents.isEmpty {
                        ForEach(groupedDays(pastEvents), id: \.date) { day in
                            eventSection(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), events: day.events, highlighted: false)
                        }
                    }
                    if selectedFilter == .past || selectedFilter == .all {
                        Button {
                            appState.openHistory()
                        } label: {
                            HStack(spacing: 6) {
                                Text("View full history")
                                Image(systemName: "chevron.right")
                                    .font(PDFont.jakarta(12, .bold, relativeTo: .footnote))
                            }
                            .font(PDFont.jakarta(15, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.pdLavender)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 1080 : .infinity)
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(agendaBackground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            captureCTA
        }
    }

    // MARK: - Chrome

    private var agendaBackground: some View {
        ZStack {
            Color.pdSurface
            RadialGradient(
                colors: [Color.pdOrange.opacity(0.12), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    /// Docked primary action; sits above the custom tab bar.
    private var captureCTA: some View {
        Button {
            appState.selectedTab = .home
        } label: {
            Label("Capture new events", systemImage: "plus")
        }
        .buttonStyle(PDGradientButtonStyle())
        .accessibilityIdentifier("agenda.capture")
        .padding(.horizontal, 16)
        .padding(.top, 10)
            .padding(.bottom, horizontalSizeClass == .regular ? 0 : 84)
        .background(
            LinearGradient(colors: [Color.pdSurface.opacity(0), Color.pdSurface], startPoint: .top, endPoint: .center)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Button { appState.openHistory() } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("agenda.history")
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.pdOrange)
                    .frame(width: 6, height: 6)
                Text("AGENDA")
                    .font(PDFont.jakarta(11, .bold, relativeTo: .caption2))
                    .tracking(1.4)
                    .foregroundStyle(Color.pdPrimary)
            }
            Text("Agenda")
                .font(PDFont.jakarta(34, .heavy, relativeTo: .largeTitle))
                .foregroundStyle(Color.pdOnSurface)
            Text("Review today\u{2019}s and upcoming saved events captured with Pencil\u{2019}d.")
                .font(PDFont.jakarta(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AgendaDateFilter.allCases) { filter in
                    let selected = filter == selectedFilter
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(PDFont.jakarta(13, .semibold, relativeTo: .footnote))
                            .foregroundStyle(selected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(selected ? AnyShapeStyle(LinearGradient.pdSelected) : AnyShapeStyle(Color.pdSurfaceContainer))
                                    .overlay(Capsule().stroke(selected ? Color.pdPrimary.opacity(0.7) : Color.pdOutlineVariant.opacity(0.5), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("agenda.filter.\(filter.id)")
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: hasActiveFilters ? "magnifyingglass" : "calendar.badge.plus")
                .font(PDFont.jakarta(34, .regular, relativeTo: .largeTitle))
                .foregroundStyle(Color.pdLavender)
            Text(hasActiveFilters ? "No matching events" : emptyTitle)
                .font(PDFont.jakarta(18, .bold, relativeTo: .title3))
                .foregroundStyle(Color.pdOnSurface)
            Text(hasActiveFilters ? "Try another event, venue, date, or filter." : emptyMessage)
                .font(PDFont.jakarta(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceContainer)
        )
    }

    private var emptyTitle: String {
        switch selectedStatus {
        case .draft: return "No draft events"
        case .archived: return "No archived events"
        case .saved: return selectedFilter == .past ? "No past events" : "Your agenda is clear"
        }
    }

    private var emptyMessage: String {
        switch selectedStatus {
        case .draft: return "Scans waiting for your review will appear here."
        case .archived: return "Events you archive will appear here."
        case .saved:
            return selectedFilter == .past
                ? "Past events will appear here when you choose the Past filter."
                : "Events you review and save will appear here."
        }
    }

    // MARK: - Sections and cards

    private func eventSection(_ title: String, events: [SavedEvent], highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(PDFont.jakarta(12, .bold, relativeTo: .footnote))
                    .tracking(1.2)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                Spacer()
                Text("\(events.count)")
                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                    .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.7))
            }
            ForEach(events) { saved in
                eventRow(saved, highlighted: highlighted)
            }
        }
    }

    private func eventRow(_ saved: SavedEvent, highlighted: Bool) -> some View {
        let candidate = saved.candidate
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                guard let event = candidate?.toPencildEvent() else { return }
                appState.activeModal = saved.status == .draft ? .eventReviewEdit(event) : .savedEventDetail(event)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    PDDateBadge(
                        month: candidate?.startDate.formatted(.dateTime.month(.abbreviated)) ?? "",
                        day: candidate?.startDate.formatted(.dateTime.day()) ?? "",
                        highlighted: highlighted
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate?.title ?? "Saved event")
                            .font(PDFont.jakarta(16, .bold, relativeTo: .body))
                            .foregroundStyle(Color.pdOnSurface)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        Text(eventSubtitle(candidate))
                            .font(PDFont.jakarta(13, .regular, relativeTo: .footnote))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(PDFont.jakarta(12, .bold, relativeTo: .footnote))
                        .foregroundStyle(Color.pdOnSurface)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.pdSurfaceHighest.opacity(0.8)))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("agenda.event.\(saved.id)")

            HStack(spacing: 8) {
                statusBadge(saved)
                Spacer(minLength: 0)
                archiveButton(saved)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(highlighted ? AnyShapeStyle(LinearGradient.pdHighlightCard) : AnyShapeStyle(Color.pdSurfaceContainer))
        )
    }

    @ViewBuilder
    private func statusBadge(_ saved: SavedEvent) -> some View {
        switch saved.status {
        case .saved:
            if saved.externalCalendarEventId != nil {
                HStack(spacing: 6) {
                    PDCheckmark(size: 16)
                    Text("In Calendar")
                        .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                        .foregroundStyle(Color.pdOnSurface)
                }
            } else {
                Label("Not in Calendar", systemImage: "exclamationmark.circle")
                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                    .foregroundStyle(Color.dsWarning)
            }
        case .draft:
            Label("Draft", systemImage: "bookmark.fill")
                .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                .foregroundStyle(Color.pdPrimary)
        case .archived:
            Label("Archived", systemImage: "archivebox.fill")
                .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }

    private func archiveButton(_ saved: SavedEvent) -> some View {
        let isArchived = saved.status == .archived
        let title = saved.candidate?.title ?? "event"
        return Button {
            let target: SavedEventStatus = isArchived ? (saved.externalCalendarEventId != nil ? .saved : .draft) : .archived
            let result = SavedEventActions(services: services, modelContext: modelContext)
                .setStatus(target, for: saved)
            let done = isArchived ? "Event restored" : "Event archived"
            switch result {
            case .success:
                appState.showToast(done)
            case .partial(let issues):
                appState.showToast("Completed with issues: \(issues.joined(separator: "; "))")
            case .failure(let error):
                appState.showToast(error.localizedDescription)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isArchived ? "arrow.uturn.backward" : "archivebox")
                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                Text(isArchived ? "Restore" : "Archive")
                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
            }
            .foregroundStyle(Color.pdOnSurface)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.pdSurfaceHighest.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isArchived ? "Restore" : "Archive") \(title)")
    }

    private func eventSubtitle(_ candidate: EventCandidate?) -> String {
        guard let candidate else { return "" }
        let date = candidate.startDate.formatted(date: .complete, time: .shortened)
        let location = candidate.venueName ?? candidate.location
        return location.map { "\(date) · \($0)" } ?? date
    }

    private func matchesSearch(_ saved: SavedEvent, candidate: EventCandidate) -> Bool {
        guard !searchText.isEmpty else { return true }
        let date = candidate.startDate.formatted(date: .complete, time: .shortened)
        return [candidate.title, candidate.venueName ?? "", candidate.location ?? "", candidate.notes, saved.targetCalendar, date]
            .contains { $0.localizedCaseInsensitiveContains(searchText) }
    }
}
