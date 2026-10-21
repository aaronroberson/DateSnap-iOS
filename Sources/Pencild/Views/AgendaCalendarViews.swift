import SwiftUI

/// List / Month / Week switcher.
struct AgendaModePicker: View {
    @Binding var mode: AgendaCalendarMode

    var body: some View {
        HStack(spacing: 4) {
            option("List", icon: "list.bullet", mode: .agenda)
            option("Month", icon: "calendar", mode: .month)
            option("Day", icon: "calendar.day.timeline.left", mode: .day)
        }
        .padding(4)
        .background(Capsule().fill(Color.pdSurfaceContainer))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar view")
    }

    private func option(_ title: String, icon: String, mode option: AgendaCalendarMode) -> some View {
        let selected = mode == option
        return Button { mode = option } label: {
            Label(title, systemImage: icon)
                .font(PDFont.labelMD)
                .foregroundStyle(selected ? Color.pdOnPrimary : Color.pdOnSurfaceVariant)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background {
                    if selected {
                        Capsule().fill(LinearGradient.pdSelected)
                    }
                }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Date-range chips (Upcoming, Today, …).
struct AgendaDateRangeBar: View {
    let selection: AgendaDateFilter
    let onSelect: (AgendaDateFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AgendaDateFilter.allCases) { range in
                    chip(range, selected: range == selection)
                }
            }
        }
    }

    private func chip(_ range: AgendaDateFilter, selected: Bool) -> some View {
        Button { onSelect(range) } label: {
            Text(range.rawValue)
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
        .accessibilityIdentifier("agenda.filter.\(range.id)")
    }
}

/// Month grid, or the week strip above the Day timeline, with previous/next navigation.
struct AgendaCalendarCard: View {
    let mode: AgendaCalendarMode
    let visibleDate: Date
    let index: AgendaDayIndex
    @Binding var selectedDate: Date
    let onMove: (Int) -> Void

    var body: some View {
        VStack(spacing: PDSpacing.sm) {
            navigation
            if mode == .month {
                monthGrid
            } else {
                weekStrip
            }
        }
        .padding(PDSpacing.md)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.pdSurfaceContainer.opacity(0.82)))
    }

    private var isMonth: Bool { mode == .month }

    private var title: String {
        isMonth
            ? AgendaCalendar.monthStart(for: visibleDate).formatted(.dateTime.month(.wide).year())
            : AgendaCalendar.weekStart(for: visibleDate).formatted(.dateTime.month(.abbreviated).day())
    }

    private var navigation: some View {
        HStack {
            arrow("chevron.left", label: isMonth ? "Previous month" : "Previous week", step: -1)
            Spacer()
            Text(title)
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdOnSurface)
            Spacer()
            arrow("chevron.right", label: isMonth ? "Next month" : "Next week", step: 1)
        }
        .foregroundStyle(Color.pdPrimary)
    }

    private func arrow(_ icon: String, label: String, step: Int) -> some View {
        Button { onMove(step) } label: {
            Image(systemName: icon)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var monthGrid: some View {
        let monthStart = AgendaCalendar.monthStart(for: visibleDate)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
            ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday.prefix(1).uppercased())
                    .font(PDFont.labelSM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .frame(maxWidth: .infinity, minHeight: 24)
            }
            ForEach(AgendaCalendar.monthGrid(for: visibleDate), id: \.self) { day in
                AgendaMonthDayCell(
                    day: day,
                    events: index.events(on: day),
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate),
                    isMuted: !Calendar.current.isDate(day, equalTo: monthStart, toGranularity: .month)
                ) { selectedDate = day }
            }
        }
    }

    private var weekStrip: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(AgendaCalendar.week(containing: visibleDate), id: \.self) { day in
                AgendaWeekDayCell(
                    day: day,
                    events: index.events(on: day),
                    isSelected: Calendar.current.isDate(day, inSameDayAs: selectedDate)
                ) { selectedDate = day }
            }
        }
    }
}

struct AgendaMonthDayCell: View {
    let day: Date
    let events: [SavedEvent]
    let isSelected: Bool
    let isMuted: Bool
    let onSelect: () -> Void

    private var numberColor: Color {
        if isSelected { return .pdPrimary }
        return isMuted ? Color.pdOnSurfaceVariant.opacity(0.45) : .pdOnSurface
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.day()))
                    .font(PDFont.labelMD)
                    .foregroundStyle(numberColor)
                    .frame(width: 28, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(LinearGradient.pdSignature.opacity(0.35))
                        }
                    }
                dots
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .top)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Color.pdPrimary.opacity(0.12) : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.month(.wide).day())), \(events.count) event\(events.count == 1 ? "" : "s")")
    }

    private var dots: some View {
        let size: CGFloat = isSelected ? 6 : 5
        return HStack(spacing: 3) {
            ForEach(events.prefix(3)) { saved in
                Circle()
                    .fill(AgendaStyle.dotColor(for: saved))
                    .frame(width: size, height: size)
            }
        }
    }
}

struct AgendaWeekDayCell: View {
    let day: Date
    let events: [SavedEvent]
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(String(day.formatted(.dateTime.weekday(.abbreviated)).prefix(3)).uppercased())
                    .font(PDFont.labelSM)
                Text(day.formatted(.dateTime.day()))
                    .font(PDFont.headlineSM)
                Circle()
                    .fill(events.first.map(AgendaStyle.dotColor) ?? Color.clear)
                    .frame(width: 6, height: 6)
            }
            .foregroundStyle(isSelected ? Color.pdOnSurface : Color.pdOnSurfaceVariant)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.pdHighlightCard) : AnyShapeStyle(Color.pdSurfaceLow))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month(.wide).day())), \(events.count) event\(events.count == 1 ? "" : "s")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
