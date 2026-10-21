import Foundation

/// How the agenda lays out its events: a dated list, a month grid, or one day's timeline under a
/// week strip.
enum AgendaCalendarMode: CaseIterable {
    case agenda, month, day
}

/// Pure date math for the agenda's month grid and week strip.
enum AgendaCalendar {
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    /// Every day of `date`'s month, preceded by the trailing days of the previous month that fill
    /// the first row up to the locale's first weekday.
    static func monthGrid(for date: Date, calendar: Calendar = .current) -> [Date] {
        let start = monthStart(for: date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 0
        return (0..<(leading + count)).compactMap { calendar.date(byAdding: .day, value: $0 - leading, to: start) }
    }

    static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let start = weekStart(for: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Moves the visible month or week by `value` and selects the first day of the new period.
    static func shift(
        _ date: Date,
        mode: AgendaCalendarMode,
        by value: Int,
        calendar: Calendar = .current
    ) -> (visible: Date, selected: Date) {
        let component: Calendar.Component = mode == .month ? .month : .weekOfYear
        let visible = calendar.date(byAdding: component, value: value, to: date) ?? date
        let selected = mode == .month
            ? monthStart(for: visible, calendar: calendar)
            : weekStart(for: visible, calendar: calendar)
        return (visible, selected)
    }
}

/// The agenda's search, status, date-range, and smart filters as one value.
struct AgendaEventFilter {
    var searchText = ""
    var dateRange: AgendaDateFilter = .upcoming
    /// `nil` while All is selected: saved, draft, and archived events together.
    var status: SavedEventStatus? = .saved
    var smartFilter: EventSmartFilter? = nil

    var isNarrowed: Bool { !searchText.isEmpty || smartFilter != nil }

    /// How many selections differ from the default (Upcoming, Saved, no search or smart filter).
    var activeCount: Int {
        let defaults = AgendaEventFilter()
        return [
            !searchText.isEmpty,
            dateRange != defaults.dateRange,
            status != defaults.status,
            smartFilter != nil
        ].filter { $0 }.count
    }

    /// All clears every other selection (status, smart filter) and includes saved, draft, and
    /// archived events. Leaving All returns to Saved if no status was picked meanwhile.
    func selecting(_ range: AgendaDateFilter) -> AgendaEventFilter {
        var next = self
        next.dateRange = range
        if range == .all {
            next.status = nil
            next.smartFilter = nil
        } else if next.status == nil {
            next.status = .saved
        }
        return next
    }

    /// Matching events, earliest first.
    @MainActor
    func apply(to events: [SavedEvent], services: ServiceContainer, now: Date = Date()) -> [SavedEvent] {
        let duplicates = smartFilter == .duplicates
            ? EventSmartFilter.duplicateIDs(in: events, services: services)
            : []
        return events
            .filter { saved in
                guard let candidate = saved.candidate,
                      status == nil || saved.status == status,
                      dateRange.includes(candidate.startDate, relativeTo: now),
                      matchesSearch(saved, candidate: candidate) else { return false }
                return smartFilter?.matches(saved, candidate: candidate, duplicates: duplicates) ?? true
            }
            .sorted { ($0.candidate?.startDate ?? .distantFuture) < ($1.candidate?.startDate ?? .distantFuture) }
    }

    func matchesSearch(_ saved: SavedEvent, candidate: EventCandidate) -> Bool {
        guard !searchText.isEmpty else { return true }
        let date = candidate.startDate.formatted(date: .complete, time: .shortened)
        return [candidate.title, candidate.venueName ?? "", candidate.location ?? "", candidate.notes, saved.targetCalendar, date]
            .contains { $0.localizedCaseInsensitiveContains(searchText) }
    }

    /// Empty-state copy for the current status and date range when nothing is narrowed by search.
    var emptyTitle: String {
        switch status {
        case .draft: return "No draft events"
        case .archived: return "No archived events"
        case .saved: return dateRange == .past ? "No past events" : "Your agenda is clear"
        case nil: return "No events yet"
        }
    }

    var emptyMessage: String {
        switch status {
        case .draft: return "Scans waiting for your review will appear here."
        case .archived: return "Events you archive will appear here."
        case .saved:
            return dateRange == .past
                ? "Past events will appear here when you choose the Past filter."
                : "Events you review and save will appear here."
        case nil: return "Saved, draft, and archived events will appear here."
        }
    }
}

/// Filtered events indexed by day, computed once per render instead of once per calendar cell.
struct AgendaDayIndex {
    let days: [(date: Date, events: [SavedEvent])]
    private let byDay: [Date: [SavedEvent]]
    private let calendar: Calendar

    init(_ events: [SavedEvent], calendar: Calendar = .current) {
        let grouped = Dictionary(grouping: events) { calendar.startOfDay(for: $0.candidate?.startDate ?? Date()) }
        self.calendar = calendar
        byDay = grouped
        days = grouped.keys.sorted().map { (date: $0, events: grouped[$0] ?? []) }
    }

    func events(on day: Date) -> [SavedEvent] {
        byDay[calendar.startOfDay(for: day)] ?? []
    }
}
