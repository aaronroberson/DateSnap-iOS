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
                .foregroundStyle(Color.dsMutedForeground)
            TextField("Search events, venues, dates...", text: $searchText)
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
                .accessibilityIdentifier("\(idPrefix).search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.dsMutedForeground)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear search")
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

    private func statusChip(_ option: SavedEventStatus) -> some View {
        let isSelected = status == option
        return Button {
            status = option
        } label: {
            HStack(spacing: 6) {
                Text(option.eventStatus.rawValue)
                    .font(DSTypography.labelChip())
                Text("\(counts[option] ?? 0)")
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
                    .overlay(Capsule().stroke(isSelected ? Color.dsPrimary : Color.dsBorder, lineWidth: 1))
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
        .accessibilityHint(locked ? PremiumFeature.duplicateClusters.upgradeReason : "Filters the event list")
        .accessibilityIdentifier("\(idPrefix).smart.\(filter.id)")
    }
}
