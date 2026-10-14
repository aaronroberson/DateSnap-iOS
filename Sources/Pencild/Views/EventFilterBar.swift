import SwiftUI
import SwiftData

/// Archive triage filters shared by History & Archive and Agenda.
enum EventSmartFilter: String, CaseIterable, Identifiable {
    case upcoming = "Upcoming"
    case rsvpDue = "RSVP Due"
    case repeating = "Repeats"
    case duplicates = "Possible Duplicates"

    var id: String { rawValue }

    /// The paid feature this filter belongs to, or `nil` for filters on every plan.
    /// Without the entitlement the chip stays visible and opens that tier's paywall.
    var requiredFeature: PremiumFeature? {
        switch self {
        case .upcoming, .repeating: return nil
        case .rsvpDue: return .advancedReminderPlans
        case .duplicates: return .duplicateClusters
        }
    }

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
        // "Upcoming" has one meaning app-wide (`AgendaDateFilter.upcoming`: from the start of today),
        // and an RSVP deadline is due until its day is over.
        case .upcoming: return AgendaDateFilter.upcoming.includes(candidate.startDate, relativeTo: now)
        case .rsvpDue: return candidate.rsvpDeadline.map { AgendaDateFilter.upcoming.includes($0, relativeTo: now) } ?? false
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
    /// `nil` shows every status (Agenda's All); no status chip is selected then.
    @Binding var status: SavedEventStatus?
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
        PDSearchField(text: $searchText, prompt: "Search events, venues, dates...", accessibilityIdentifier: "\(idPrefix).search")
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
        let feature = filter.requiredFeature
        let locked = feature.map { !appState.isEntitled(to: $0) } ?? false
        return Button {
            if let feature, locked {
                appState.showToast(feature.upgradeReason)
                Task { await appState.present(.paywall(for: feature)) }
            } else {
                smartFilter = isSelected ? nil : filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: locked ? "lock.fill" : filter.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(filter.rawValue)
                    .font(PDFont.bodySM)
                if let feature {
                    PDTierTag(tier: feature.requiredTier)
                }
            }
            .foregroundStyle(isSelected ? palette.selectedText : palette.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                Capsule()
                    .fill(isSelected ? palette.selectedFill
                          : feature != nil ? AnyShapeStyle(LinearGradient.pdPaidFeature)
                          : AnyShapeStyle(palette.chipFill))
            )
            .overlay(
                Capsule().stroke(isSelected && feature != nil ? palette.selectedBorder : Color.clear, lineWidth: 1)
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(locked ? (feature?.upgradeReason ?? "") : "Filters the event list")
        .accessibilityIdentifier("\(idPrefix).smart.\(filter.id)")
    }
}
