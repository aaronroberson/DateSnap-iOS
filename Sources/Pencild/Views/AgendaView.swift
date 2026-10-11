import SwiftUI
import SwiftData

struct AgendaView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]

    @State private var searchText = ""
    @State private var selectedFilter: AgendaDateFilter = .upcoming

    private var agendaEvents: [SavedEvent] {
        savedEvents
            .filter { $0.status == .saved && $0.candidate != nil }
            .filter { saved in
                guard let candidate = saved.candidate else { return false }
                return selectedFilter.includes(candidate.startDate, relativeTo: Date()) && matchesSearch(saved, candidate: candidate)
            }
            .sorted { ($0.candidate?.startDate ?? .distantFuture) < ($1.candidate?.startDate ?? .distantFuture) }
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchField
                dateFilters

                if agendaEvents.isEmpty {
                    emptyState
                } else {
                    if !todayEvents.isEmpty {
                        eventSection("Today’s events", events: todayEvents)
                    }
                    if !upcomingEvents.isEmpty {
                        eventSection("Upcoming events", events: upcomingEvents)
                    }
                    if !pastEvents.isEmpty {
                        eventSection("Past events", events: pastEvents)
                    }
                    if selectedFilter == .past || selectedFilter == .all {
                        Button {
                            appState.selectedTab = .history
                        } label: {
                            Label("View full history", systemImage: "arrow.right")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .dsScreenBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("PENCIL’D • AGENDA")
                .font(DSTypography.overlineConfidence())
                .foregroundStyle(Color.dsPrimary)
            Text("Agenda")
                .font(DSTypography.displayTitle())
                .foregroundStyle(Color.dsForeground)
            Text("Review today’s and upcoming saved events.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.dsMutedForeground)
            TextField("Search events, venues, dates…", text: $searchText)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
                .accessibilityIdentifier("agenda.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.dsMutedForeground)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear agenda search")
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.dsCard)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.dsBorder, lineWidth: 1))
        )
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
                            .font(DSTypography.labelChip())
                            .foregroundStyle(selected ? Color.dsPrimary : Color.dsMutedForeground)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.dsPrimary.opacity(0.14) : Color.dsCard)
                                    .overlay(Capsule().stroke(selected ? Color.dsPrimary : Color.dsBorder, lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("agenda.filter.\(filter.id)")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "calendar.badge.plus" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(Color.dsSecondary)
            Text(searchText.isEmpty ? emptyTitle : "No matching events")
                .font(DSTypography.headlineCard())
                .foregroundStyle(Color.dsForeground)
            Text(searchText.isEmpty ? emptyMessage : "Try another event, venue, or date.")
                .font(DSTypography.caption())
                .foregroundStyle(Color.dsMutedForeground)
                .multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button {
                    appState.selectedTab = .home
                } label: {
                    Label("Capture new events", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(DSPrimaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .dsGlassCard()
    }

    private var emptyTitle: String {
        selectedFilter == .past ? "No past events" : "Your agenda is clear"
    }

    private var emptyMessage: String {
        selectedFilter == .past
            ? "Past events will appear here when you choose the Past filter."
            : "Events you review and save will appear here."
    }

    private func eventSection(_ title: String, events: [SavedEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(DSTypography.headlineCard())
                    .foregroundStyle(Color.dsForeground)
                Spacer()
                Text("\(events.count)")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
            ForEach(events) { saved in
                eventRow(saved)
            }
        }
    }

    private func eventRow(_ saved: SavedEvent) -> some View {
        let candidate = saved.candidate
        return HStack(spacing: 10) {
            Button {
                guard let event = candidate?.toPencildEvent() else { return }
                appState.activeModal = .savedEventDetail(event)
            } label: {
                HStack(spacing: 12) {
                    DSDateBadge(
                        month: candidate?.startDate.formatted(.dateTime.month(.abbreviated)) ?? "",
                        day: candidate?.startDate.formatted(.dateTime.day()) ?? "",
                        isSelected: true
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate?.title ?? "Saved event")
                            .font(DSTypography.bodyStrong())
                            .foregroundStyle(Color.dsForeground)
                            .lineLimit(2)
                        Text(eventSubtitle(candidate))
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("agenda.event.\(saved.id)")

            Button {
                let result = SavedEventActions(services: services, modelContext: modelContext)
                    .setStatus(.archived, for: saved)
                switch result {
                case .success:
                    appState.showToast("Event archived")
                case .partial(let issues):
                    appState.showToast("Archived with issues: \(issues.joined(separator: "; "))")
                case .failure(let error):
                    appState.showToast(error.localizedDescription)
                }
            } label: {
                Image(systemName: "archivebox")
                    .foregroundStyle(Color.dsMutedForeground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Archive \(candidate?.title ?? "event")")
        }
        .padding(12)
        .dsGlassCard(cornerRadius: 16)
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
