import SwiftUI

/// Search and filters for the Agenda (Stitch "Calendar Filter & Search Hub"), pushed from the
/// Agenda header so the agenda itself stays a single uncluttered list or calendar.
struct AgendaFilterHub: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filter: AgendaEventFilter
    /// Every saved event, for the status counts.
    let events: [SavedEvent]
    let resultCount: Int

    private var statusCounts: [SavedEventStatus: Int] {
        Dictionary(uniqueKeysWithValues: SavedEventStatus.allCases.map { status in
            (status, events.filter { $0.status == status && $0.candidate != nil }.count)
        })
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Button { dismiss() } label: {
                    Label("Agenda", systemImage: "chevron.left")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                }
                .accessibilityIdentifier("agenda.filters.back")
                PDScreenIntro(
                    eyebrow: "Search & Filter",
                    title: "Find events",
                    subtitle: "Search titles, venues, notes, and dates."
                )
                EventSearchFilterBar(
                    searchText: $filter.searchText,
                    status: $filter.status,
                    smartFilter: $filter.smartFilter,
                    counts: statusCounts,
                    excludedSmartFilters: [.upcoming],
                    idPrefix: "agenda",
                    palette: .pencild
                )
                VStack(alignment: .leading, spacing: 8) {
                    Text("TIMELINE")
                        .font(PDFont.labelSM)
                        .tracking(1.2)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    AgendaDateRangeBar(selection: filter.dateRange) { filter = filter.selecting($0) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.pdSurface.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private var footer: some View {
        HStack(spacing: PDSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(resultCount) event\(resultCount == 1 ? "" : "s")")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Text("\(filter.activeCount) active filter\(filter.activeCount == 1 ? "" : "s")")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
            Spacer()
            Button("Reset") { filter = AgendaEventFilter() }
                .font(PDFont.labelLG)
                .foregroundStyle(Color.pdPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(filter.activeCount == 0)
                .accessibilityIdentifier("agenda.filters.reset")
            Button("Done") { dismiss() }
                .buttonStyle(PDPrimaryButtonStyle(minHeight: 44))
                .fixedSize()
                .accessibilityIdentifier("agenda.filters.done")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.pdSurfaceContainer.ignoresSafeArea(edges: .bottom))
    }
}

/// Shown on the Agenda while filters differ from the default, so hidden filters aren't a mystery.
struct AgendaActiveFilters: View {
    let count: Int
    let onEdit: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            Button(action: onEdit) {
                Label("\(count) filter\(count == 1 ? "" : "s") on", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdPrimary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(Capsule().fill(Color.pdSurfaceContainer))
            }
            .accessibilityHint("Opens search and filters")
            Button("Clear", action: onReset)
                .font(PDFont.labelMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Clear filters")
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("agenda.activeFilters")
    }
}
