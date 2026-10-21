import SwiftUI

/// Shared agenda colors and copy derived from an event.
enum AgendaStyle {
    static func dotColor(for saved: SavedEvent) -> Color {
        guard let medium = saved.candidate?.scannedAsset?.sourceMedium else { return .pdSecondary }
        switch medium {
        case .flyer, .screenshot, .photo: return .pdTertiary
        case .pdf, .file, .schedule: return .pdPrimary
        case .ticket, .appleWallet: return .pdSecondary
        case .textInvite, .ocrScan: return .pdLavender
        }
    }

    static func subtitle(for candidate: EventCandidate?) -> String {
        guard let candidate else { return "" }
        let date = candidate.startDate.formatted(date: .complete, time: .shortened)
        let location = candidate.venueName ?? candidate.location
        return location.map { "\(date) · \($0)" } ?? date
    }
}

/// One day's events in List mode, with a count in the header.
struct AgendaEventSection: View {
    let title: String
    let events: [SavedEvent]
    let highlighted: Bool
    let onOpen: (SavedEvent) -> Void
    let onToggleArchive: (SavedEvent) -> Void

    var body: some View {
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
                AgendaEventRow(
                    saved: saved,
                    highlighted: highlighted,
                    onOpen: { onOpen(saved) },
                    onToggleArchive: { onToggleArchive(saved) }
                )
            }
        }
    }
}

struct AgendaEventRow: View {
    let saved: SavedEvent
    let highlighted: Bool
    let onOpen: () -> Void
    let onToggleArchive: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) { summary }
                .buttonStyle(.plain)
                .accessibilityIdentifier("agenda.event.\(saved.id)")
            HStack(spacing: 8) {
                AgendaStatusBadge(saved: saved)
                Spacer(minLength: 0)
                AgendaArchiveButton(
                    isArchived: saved.status == .archived,
                    title: saved.candidate?.title ?? "event",
                    action: onToggleArchive
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(highlighted ? AnyShapeStyle(LinearGradient.pdHighlightCard) : AnyShapeStyle(Color.pdSurfaceContainer))
        )
    }

    private var summary: some View {
        let candidate = saved.candidate
        return HStack(alignment: .top, spacing: 12) {
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
                Text(AgendaStyle.subtitle(for: candidate))
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
}

struct AgendaStatusBadge: View {
    let saved: SavedEvent

    private let font = PDFont.jakarta(12, .semibold, relativeTo: .footnote)

    var body: some View {
        switch saved.status {
        case .saved where saved.externalCalendarEventId != nil:
            HStack(spacing: 6) {
                PDCheckmark(size: 16)
                Text("In Calendar")
                    .font(font)
                    .foregroundStyle(Color.pdOnSurface)
            }
        case .saved:
            Label("Not in Calendar", systemImage: "exclamationmark.circle")
                .font(font)
                .foregroundStyle(Color.pdWarning)
        case .draft:
            Label("Draft", systemImage: "bookmark.fill")
                .font(font)
                .foregroundStyle(Color.pdPrimary)
        case .archived:
            Label("Archived", systemImage: "archivebox.fill")
                .font(font)
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }
}

struct AgendaArchiveButton: View {
    let isArchived: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isArchived ? "arrow.uturn.backward" : "archivebox")
                Text(isArchived ? "Restore" : "Archive")
            }
            .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
            .foregroundStyle(Color.pdOnSurface)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().fill(Color.pdSurfaceHighest.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isArchived ? "Restore" : "Archive") \(title)")
    }
}

/// The selected day's events under the month grid, or as a timeline with a time gutter in Day mode.
struct AgendaFocusedDay: View {
    let date: Date
    let events: [SavedEvent]
    var showsTimes = false
    let onOpen: (SavedEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            header
            if events.isEmpty {
                Text("Nothing scheduled for this day.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PDSpacing.md)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.pdSurfaceLow))
            } else {
                ForEach(events) { saved in
                    if showsTimes {
                        timelineRow(saved)
                    } else {
                        AgendaFocusedEventCard(saved: saved) { onOpen(saved) }
                    }
                }
            }
        }
    }

    private func timelineRow(_ saved: SavedEvent) -> some View {
        HStack(alignment: .top, spacing: PDSpacing.sm) {
            Text(saved.candidate?.startDate.formatted(date: .omitted, time: .shortened) ?? "")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdPrimary)
                .frame(width: 64, alignment: .trailing)
                .padding(.top, PDSpacing.md)
            AgendaFocusedEventCard(saved: saved) { onOpen(saved) }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(showsTimes ? "DAY TIMELINE" : "FOCUSED AGENDA")
                    .font(PDFont.labelSM)
                    .tracking(1.2)
                    .foregroundStyle(Color.pdPrimary)
                Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()))
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
            }
            Spacer()
            Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                .font(PDFont.labelSM)
                .foregroundStyle(Color.pdPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.pdSurfaceContainerHigh))
        }
    }
}

struct AgendaFocusedEventCard: View {
    let saved: SavedEvent
    let onOpen: () -> Void

    private var isDraft: Bool { saved.status == .draft }
    private var tint: Color { AgendaStyle.dotColor(for: saved) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top, spacing: PDSpacing.sm) {
                    VStack(alignment: .leading, spacing: 5) {
                        sourceTag
                        Text(saved.candidate?.title ?? "Saved event")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                details
            }
            .padding(PDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isDraft ? AnyShapeStyle(LinearGradient.pdHighlightCard) : AnyShapeStyle(Color.pdSurfaceContainer.opacity(0.9)))
            )
        }
        .buttonStyle(.plain)
    }

    private var sourceTag: some View {
        HStack(spacing: 6) {
            Text(saved.candidate?.scannedAsset?.sourceMedium.rawValue ?? "Manual entry")
            Text("•")
            Text(isDraft ? "Draft" : "Saved")
        }
        .font(PDFont.labelSM)
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
    }

    private var details: some View {
        let candidate = saved.candidate
        return HStack(spacing: PDSpacing.md) {
            Label(candidate?.startDate.formatted(date: .omitted, time: .shortened) ?? "", systemImage: "clock")
            if let location = candidate?.location ?? candidate?.venueName, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .lineLimit(1)
            }
        }
        .font(PDFont.bodySM)
        .foregroundStyle(Color.pdOnSurfaceVariant)
    }
}

struct AgendaEmptyState: View {
    let isFiltered: Bool
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isFiltered ? "magnifyingglass" : "calendar.badge.plus")
                .font(PDFont.jakarta(34, .regular, relativeTo: .largeTitle))
                .foregroundStyle(Color.pdLavender)
            Text(isFiltered ? "No matching events" : title)
                .font(PDFont.jakarta(18, .bold, relativeTo: .title3))
                .foregroundStyle(Color.pdOnSurface)
            Text(isFiltered ? "Try another event, venue, date, or filter." : message)
                .font(PDFont.jakarta(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceContainer))
    }
}
