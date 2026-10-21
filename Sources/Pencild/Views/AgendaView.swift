import SwiftUI
import SwiftData

/// Agenda tab (Stitch "Agenda", "Monthly Grid Calendar", "Day Timeline Schedule"). One mode is on
/// screen at a time; search and filters live on their own screen (`AgendaFilterHub`).
struct AgendaView: View {
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedEvent.createdAt, order: .reverse) private var savedEvents: [SavedEvent]

    @State private var filter = AgendaEventFilter()
    @State private var mode: AgendaCalendarMode = .agenda
    @State private var visibleDate = Date()
    @State private var selectedDate = Date()
    @State private var showFilters = false

    var body: some View {
        let events = filter.apply(to: savedEvents, services: services)
        let index = AgendaDayIndex(events)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                AgendaModePicker(mode: $mode)
                if filter.activeCount > 0 {
                    AgendaActiveFilters(count: filter.activeCount, onEdit: { showFilters = true }) {
                        filter = AgendaEventFilter()
                    }
                }
                content(events: events, index: index)
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 1080 : .infinity)
            .padding(.horizontal, horizontalSizeClass == .regular ? 28 : 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background(background)
        .safeAreaInset(edge: .bottom, spacing: 0) { captureCTA }
        .navigationDestination(isPresented: $showFilters) {
            AgendaFilterHub(filter: $filter, events: savedEvents, resultCount: events.count)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    // MARK: - Modes

    @ViewBuilder
    private func content(events: [SavedEvent], index: AgendaDayIndex) -> some View {
        switch mode {
        case .agenda:
            if events.isEmpty {
                emptyState
            } else {
                ForEach(index.days, id: \.date) { day in
                    AgendaEventSection(
                        title: sectionTitle(for: day.date),
                        events: day.events,
                        highlighted: Calendar.current.isDateInToday(day.date),
                        onOpen: open,
                        onToggleArchive: toggleArchive
                    )
                }
            }
            if filter.dateRange == .upcoming {
                pastEventsLink
            }
        case .month, .day:
            AgendaCalendarCard(
                mode: mode,
                visibleDate: visibleDate,
                index: index,
                selectedDate: $selectedDate,
                onMove: move
            )
            if events.isEmpty {
                emptyState
            } else {
                AgendaFocusedDay(
                    date: selectedDate,
                    events: index.events(on: selectedDate),
                    showsTimes: mode == .day,
                    onOpen: open
                )
            }
        }
    }

    private func sectionTitle(for day: Date) -> String {
        Calendar.current.isDateInToday(day)
            ? "Today\u{2019}s events"
            : day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var pastEventsLink: some View {
        Button {
            filter = filter.selecting(.past)
        } label: {
            Label("View past events", systemImage: "arrow.right")
                .labelStyle(TrailingIconLabelStyle())
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("agenda.pastEvents")
    }

    private var emptyState: some View {
        AgendaEmptyState(isFiltered: filter.isNarrowed, title: filter.emptyTitle, message: filter.emptyMessage)
    }

    // MARK: - Chrome

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Spacer()
                Button { showFilters = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(PDFont.labelLG)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Search and filter events")
                .accessibilityIdentifier("agenda.search")
                Button { appState.openHistory() } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(PDFont.labelLG)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("agenda.history")
            }
            .foregroundStyle(Color.pdPrimary)
            PDScreenIntro(
                eyebrow: "Calendar Agenda",
                title: "Agenda",
                subtitle: "Review today’s Pencil’d events."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var background: some View {
        ZStack {
            Color.pdSurface
            RadialGradient(colors: [Color.pdOrange.opacity(0.12), .clear], center: .top, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    /// Docked primary action; sits above the custom tab bar.
    private var captureCTA: some View {
        Button {
            Task { await appState.present(.captureSources) }
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

    // MARK: - Actions

    private func move(by step: Int) {
        let next = AgendaCalendar.shift(visibleDate, mode: mode, by: step)
        visibleDate = next.visible
        selectedDate = next.selected
    }

    private func open(_ saved: SavedEvent) {
        guard let event = saved.candidate?.toPencildEvent() else { return }
        Task { await appState.present(saved.status == .draft ? .eventReviewEdit(event) : .savedEventDetail(event)) }
    }

    private func toggleArchive(_ saved: SavedEvent) {
        let isArchived = saved.status == .archived
        let target: SavedEventStatus = isArchived ? (saved.externalCalendarEventId != nil ? .saved : .draft) : .archived
        switch SavedEventActions(services: services, modelContext: modelContext).setStatus(target, for: saved) {
        case .success:
            appState.showToast(isArchived ? "Event restored" : "Event archived")
        case .partial(let issues):
            appState.showToast("Completed with issues: \(issues.joined(separator: "; "))")
        case .failure(let error):
            appState.showToast(error.localizedDescription)
        }
    }
}
