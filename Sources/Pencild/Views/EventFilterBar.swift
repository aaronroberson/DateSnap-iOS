import SwiftUI
import SwiftData

/// Archive triage filters shared by History & Archive and Agenda.
enum EventSmartFilter: String, CaseIterable, Identifiable {
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

    func matches(_ saved: SavedEvent, candidate: EventCandidate, duplicates: Set<String>) -> Bool {
        let now = Date()
        switch self {
        case .upcoming: return candidate.startDate >= now
        case .rsvpDue: return (candidate.rsvpDeadline.map { $0 >= Calendar.current.startOfDay(for: now) }) ?? false
        case .repeating: return candidate.recurrenceRaw != nil || candidate.interpretation?.stored?.understanding.recurrence != nil
        case .duplicates: return duplicates.contains(saved.id)
        }
    }

    /// IDs of saved records that belong to a likely-duplicate cluster (Premium).
    @MainActor
    static func duplicateIDs(in savedEvents: [SavedEvent], services: ServiceContainer) -> Set<String> {
        let entries = savedEvents.compactMap { saved -> EventSimilarityService.Entry? in
            guard let candidate = saved.candidate else { return nil }
            return EventSimilarityService.Entry(id: saved.id, similarityKey: candidate.similarityKey, title: candidate.title,
                                                start: candidate.startDate, isSaved: saved.status == .saved)
        }
        return Set(EventSimilarityService.premiumClusters(
            entries,
            snapshot: services.subscription.entitlementSnapshot
        ).flatMap { $0.map(\.id) })
    }
}

/// Colors for `EventSearchFilterBar`. `legacy` keeps History & Archive on the
/// current app palette; `pencild` is the Stitch "Luminous Precision" look.
struct EventFilterPalette {
    let text: Color
    let muted: Color
    let accent: Color
    let fieldFill: Color
    let chipFill: Color
    let border: Color
    let selectedFill: AnyShapeStyle
    let selectedBorder: Color
    let selectedText: Color
    let countFill: Color
    let selectedCountFill: Color
    let showsCheckmark: Bool

    static let legacy = EventFilterPalette(
        text: .pdOnSurface,
        muted: .pdOnSurfaceVariant,
        accent: .pdPrimary,
        fieldFill: .pdSurfaceContainer,
        chipFill: .pdSurfaceContainer,
        border: Color.pdSurfaceHighest.opacity(0.6),
        selectedFill: AnyShapeStyle(Color.pdSecondary.opacity(0.2)),
        selectedBorder: .pdPrimary,
        selectedText: .pdPrimary,
        countFill: Color.white.opacity(0.1),
        selectedCountFill: Color.pdPrimary.opacity(0.3),
        showsCheckmark: false
    )

    static let pencild = EventFilterPalette(
        text: .pdOnSurface,
        muted: .pdOnSurfaceVariant,
        accent: .pdPrimary,
        fieldFill: .pdSurfaceContainer,
        chipFill: .pdSurfaceContainer,
        border: Color.pdOutlineVariant.opacity(0.5),
        selectedFill: AnyShapeStyle(LinearGradient.pdSelected),
        selectedBorder: Color.pdPrimary.opacity(0.7),
        selectedText: .pdPrimary,
        countFill: Color.pdSurfaceHighest,
        selectedCountFill: Color.pdOrange.opacity(0.28),
        showsCheckmark: true
    )
}

/// Search field, status chips (with counts) and smart triage chips. Used at the
/// top of both History & Archive and Agenda so the two stay identical.
struct EventSearchFilterBar: View {
    @EnvironmentObject private var appState: AppState

    @Binding var searchText: String
    @Binding var status: SavedEventStatus
    @Binding var smartFilter: EventSmartFilter?
    let counts: [SavedEventStatus: Int]
    var excludedSmartFilters: Set<EventSmartFilter> = []
    var idPrefix: String = "events"
    var palette: EventFilterPalette = .legacy

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(SavedEventStatus.allCases, id: \.self) { option in
                        statusChip(option)
                    }
                }
                .padding(.vertical, 8)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EventSmartFilter.allCases.filter { !excludedSmartFilters.contains($0) }) { filter in
                        smartFilterChip(filter)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(palette.muted)
            TextField("Search events, venues, dates...", text: $searchText)
                .font(PDFont.jakarta(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(palette.text)
                .accessibilityIdentifier("\(idPrefix).search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(palette.muted)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.leading, 14)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(palette.fieldFill)
        )
    }

    private func statusChip(_ option: SavedEventStatus) -> some View {
        let isSelected = status == option
        return Button {
            status = option
        } label: {
            HStack(spacing: 6) {
                if isSelected && palette.showsCheckmark {
                    PDCheckmark(size: 16)
                }
                Text(option.eventStatus.rawValue)
                    .font(PDFont.labelMD)
                Text("\(counts[option] ?? 0)")
                    .font(PDFont.labelSM)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(isSelected ? palette.selectedCountFill : palette.countFill)
                    )
            }
            .foregroundStyle(isSelected ? palette.selectedText : palette.muted)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? palette.selectedFill : AnyShapeStyle(palette.chipFill))
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("\(idPrefix).status.\(option.rawValue)")
    }

    private func smartFilterChip(_ filter: EventSmartFilter) -> some View {
        let isSelected = smartFilter == filter
        let locked = filter == .duplicates && !appState.isEntitled(to: .duplicateClusters)
        return Button {
            if locked {
                Task { await appState.present(.premiumPaywall) }
            } else {
                smartFilter = isSelected ? nil : filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: locked ? "lock.fill" : filter.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(filter.rawValue)
                    .font(PDFont.bodySM)
            }
            .foregroundStyle(isSelected ? palette.selectedText : palette.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? palette.selectedFill : AnyShapeStyle(palette.chipFill))
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(locked ? PremiumFeature.duplicateClusters.upgradeReason : "Filters the event list")
        .accessibilityIdentifier("\(idPrefix).smart.\(filter.id)")
    }
}
