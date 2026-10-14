import SwiftUI
import SwiftData

// MARK: - Capture sources
/// The ways to add an event, in display order. Home and the "Add events" sheet both list these, so
/// their labels, icons and order stay identical.
enum CaptureSource: String, CaseIterable, Identifiable {
    case screenshots
    case photoLibrary
    case fileImport
    case documentScanner
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenshots: return "Screenshots"
        case .photoLibrary: return "Photo Library"
        case .fileImport: return "PDF & Files Import"
        case .documentScanner: return "Document Scanner"
        case .manual: return "Enter Manually"
        }
    }

    var detail: String {
        switch self {
        case .screenshots: return "Find event flyers, tickets, and invitations in the screenshots you choose."
        case .photoLibrary: return "Choose from your saved photos, whiteboards, or custom albums."
        case .fileImport: return "Multi-page conference schedules, syllabi, flight itineraries & documents."
        case .documentScanner: return "Capture and straighten paper flyers and multi-page documents with the camera."
        case .manual: return "Type it in with your default calendar and reminders already applied."
        }
    }

    /// Short tag line for the tile grid (sheet and welcome screen).
    var shortDetail: String {
        switch self {
        case .screenshots: return "Flyers & invites"
        case .photoLibrary: return "Posters & notes"
        case .fileImport: return "Itineraries & syllabi"
        case .documentScanner: return "Paper flyers"
        case .manual: return "Type it in"
        }
    }

    var icon: String {
        switch self {
        case .screenshots: return "rectangle.dashed.badge.record"
        case .photoLibrary: return "photo.on.rectangle"
        case .fileImport: return "doc"
        case .documentScanner: return "doc.viewfinder"
        case .manual: return "square.and.pencil"
        }
    }

    var tint: Color {
        switch self {
        case .screenshots, .manual: return .pdPrimary
        case .photoLibrary, .documentScanner: return .pdSecondary
        case .fileImport: return .pdTertiary
        }
    }

    var chips: [String] {
        switch self {
        case .screenshots: return ["Recent", "Multi-select"]
        case .photoLibrary: return ["Albums", "Camera Roll", "Favorites"]
        case .fileImport: return ["PDF", "Images", "iCloud Drive"]
        case .documentScanner: return ["Camera", "Multi-page", "On-device"]
        case .manual: return ["Default calendar", "Default reminders"]
        }
    }

    /// The paid feature this source needs, or `nil` when it is on every plan.
    var requiredFeature: PremiumFeature? {
        self == .fileImport ? .documentImport : nil
    }

    var accessibilityHint: String {
        switch self {
        case .screenshots: return "Shows your recent screenshots to scan"
        case .photoLibrary: return "Opens your photo library"
        case .fileImport: return "Scan a PDF or image from Files"
        case .documentScanner: return "Opens the document camera"
        case .manual: return "Opens a blank event form"
        }
    }
}

// MARK: - Source row (shared by Home and the sheet)
/// One capture source as a tappable card. Paid sources stay visible; the row shows the tier tag and
/// a lock when the plan doesn't include it, and the caller opens the paywall on tap.
struct CaptureSourceRow: View {
    @EnvironmentObject private var appState: AppState
    let source: CaptureSource
    let action: () -> Void

    private var locked: Bool {
        source.requiredFeature.map { !appState.isEntitled(to: $0) } ?? false
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: PDSpacing.md) {
                Image(systemName: locked ? "lock.fill" : source.icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(source.tint)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceContainerHigh))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(source.title)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        if let feature = source.requiredFeature {
                            PDTierTag(tier: feature.requiredTier)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Text(source.detail)
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    chipRow
                        .padding(.top, PDSpacing.xs)
                }
            }
            .padding(PDSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: PDRadius.card)
                    .fill(source.requiredFeature != nil
                          ? AnyShapeStyle(LinearGradient.pdPaidFeature)
                          : AnyShapeStyle(Color.pdSurfaceContainer.opacity(0.75)))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint(locked ? (source.requiredFeature?.upgradeReason ?? "") : source.accessibilityHint)
        .accessibilityIdentifier("capture.\(source.id)")
    }

    /// Pills on one line only: if they don't all fit, trailing pills are dropped rather than wrapped.
    private var chipRow: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(stride(from: source.chips.count, through: 1, by: -1)), id: \.self) { count in
                HStack(spacing: PDSpacing.xs) {
                    ForEach(source.chips.prefix(count), id: \.self) { chip in
                        Text(chip)
                            .font(PDFont.labelSM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, PDSpacing.xs)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.pdSurfaceHighest))
                    }
                }
            }
            EmptyView()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Source grid (sheet and welcome screen)
/// Dense tile grid of every capture source: icon, name and a short tag line. Used where the full
/// Home descriptions would crowd the screen (the Add events sheet and the welcome page).
struct CaptureSourceGrid: View {
    @EnvironmentObject private var appState: AppState
    let action: (CaptureSource) -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(CaptureSource.allCases) { source in
                tile(source)
            }
        }
    }

    private func tile(_ source: CaptureSource) -> some View {
        let locked = source.requiredFeature.map { !appState.isEntitled(to: $0) } ?? false
        return Button { action(source) } label: {
            VStack(spacing: 6) {
                Image(systemName: locked ? "lock.fill" : source.icon)
                    .font(PDFont.jakarta(17, .regular, relativeTo: .body))
                    .foregroundStyle(source.tint)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                Text(source.title)
                    .font(PDFont.jakarta(12, .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.pdOnSurface)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(source.shortDetail)
                    .font(PDFont.jakarta(10, .regular, relativeTo: .caption2))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let feature = source.requiredFeature {
                    PDTierTag(tier: feature.requiredTier)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(source.requiredFeature != nil ? AnyShapeStyle(LinearGradient.pdPaidFeature) : AnyShapeStyle(Color.pdSurfaceLow))
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(source.title)
        .accessibilityHint(locked ? (source.requiredFeature?.upgradeReason ?? "") : source.accessibilityHint)
        .accessibilityIdentifier("capture.tile.\(source.id)")
    }
}

// MARK: - Add events sheet
/// The Add events sheet (formerly the launch carousel's second page): brand header, every capture
/// source as a tile, and the newest scan waiting for review. Scan sources hand off to Home, which
/// owns the pickers, scan limits and batch prompts; Enter Manually opens the event form.
enum CaptureSheetCopy {
    static let welcomeLead = "Scanned. Reviewed. "
    static let welcomeAccent = "Pencil’d."
    static let welcomeBody = "Select screenshots, physical flyers, invites, tickets, or PDFs. Review the detected details before saving to your calendar."
    static let privacyBody = "Pencil’d detects screenshots containing dates, venues, or meeting links directly on your phone."
    static let privacyLine = "Your scans are processed on this device."
}

struct CaptureSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState

    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    PDCloseButton(accessibilityLabel: "Close")
                }
                Image("PencildMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)

                (Text(CaptureSheetCopy.welcomeLead).foregroundStyle(Color.pdOnSurface)
                    + Text(CaptureSheetCopy.welcomeAccent).foregroundStyle(LinearGradient.pdHeadline))
                    .font(PDFont.jakarta(30, .bold, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Text(CaptureSheetCopy.welcomeBody)
                    .font(PDFont.jakarta(16, .regular, relativeTo: .body))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .padding(.top, 8)

                VStack(spacing: 10) {
                    HStack {
                        Text("ADD EVENTS FROM")
                            .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                            .tracking(1.2)
                        Spacer()
                        Text("On-device OCR")
                            .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                            .opacity(0.7)
                    }
                    .foregroundStyle(Color.pdOnSurfaceVariant)

                    CaptureSourceGrid { choose($0) }
                }
                .frame(maxWidth: 380)
                .padding(.top, 28)

                libraryCard
                    .frame(maxWidth: 380)
                    .padding(.top, 24)

                Label(CaptureSheetCopy.privacyLine, systemImage: "lock")
                    .font(PDFont.jakarta(11, .semibold, relativeTo: .caption2))
                    .foregroundStyle(Color.pdOnSurfaceVariant.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                    .padding(.top, 24)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, PDSpacing.sm)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: From your library

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("From your library", systemImage: "photo.on.rectangle")
                    .font(PDFont.jakarta(18, .semibold, relativeTo: .title3))
                    .foregroundStyle(Color.pdOnSurface)
                Spacer(minLength: 8)
                Label("Private on-device", systemImage: "checkmark.shield")
                    .font(PDFont.jakarta(10, .bold, relativeTo: .caption2))
                    .tracking(0.6)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.pdSurfaceContainerHigh))
            }
            Text(CaptureSheetCopy.privacyBody)
                .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                .foregroundStyle(Color.pdOnSurfaceVariant)

            if let latest = candidates.first(where: \.needsReview) {
                Button(action: openReviewQueue) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.open")
                            .font(PDFont.jakarta(18, .regular, relativeTo: .title3))
                            .foregroundStyle(Color.pdLavender)
                            .frame(width: 40, height: 40)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainer))
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("“\(latest.title)”")
                                    .font(PDFont.jakarta(12, .semibold, relativeTo: .footnote))
                                    .foregroundStyle(Color.pdOnSurface)
                                    .lineLimit(1)
                                Spacer(minLength: 6)
                                Text("Found \(latest.createdAt.formatted(.relative(presentation: .named)))")
                                    .font(PDFont.jakarta(10, .bold, relativeTo: .caption2))
                                    .foregroundStyle(Color.pdPrimary)
                                    .lineLimit(1)
                            }
                            Text(candidateDetail(latest))
                                .font(PDFont.jakarta(12, .regular, relativeTo: .footnote))
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(PDFont.jakarta(13, .semibold, relativeTo: .footnote))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceLow))
                }
                .accessibilityHint("Opens the review queue")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.pdSurfaceContainer))
    }

    private func choose(_ source: CaptureSource) {
        if source == .manual {
            Task { await appState.startManualEntry(in: modelContext) }
        } else {
            Task { await appState.beginCapture(source) }
        }
    }

    private func openReviewQueue() {
        appState.selectedTab = .review
        dismiss()
    }

    private func candidateDetail(_ candidate: EventCandidate) -> String {
        let when = candidate.startDate.formatted(date: .abbreviated, time: candidate.isAllDay ? .omitted : .shortened)
        guard let place = candidate.venueName ?? candidate.location, !place.isEmpty else { return when }
        return "\(when) • \(place)"
    }
}

// MARK: - Manual entry
/// The one place blank events are built. Enter Manually makes a source-less event (marked
/// `isManualEntry`: no source image or confidence in the form, deleted if closed without a save or
/// draft). No Dates Found passes the scan as a prefill, so the event keeps its flyer and stays in
/// Review like any other scan. Both go through the review form with the default calendar and
/// default reminders applied.
enum ManualEventFactory {
    /// Text carried over from a scan that found no dates.
    struct ScanPrefill {
        var title: String
        var rawText: String
    }

    @MainActor
    static func makeCandidate(
        in context: ModelContext,
        prefill: ScanPrefill? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> EventCandidate {
        let nextHour = calendar.dateInterval(of: .hour, for: now).map(\.end) ?? now
        let fromScan = prefill != nil
        let candidate = EventCandidate(
            title: prefill?.title ?? "",
            startDate: nextHour,
            endDate: EventDurationPolicy.fallbackEnd(for: nextHour),
            confidenceScore: fromScan ? 0 : 1,
            rawTextSnippet: prefill?.rawText ?? "",
            dateConfidence: fromScan ? 0 : 1,
            titleConfidence: fromScan ? 0 : 1,
            confidenceTierRaw: (fromScan ? ConfidenceTier.low : .high).rawValue,
            timeZoneIdentifier: calendar.timeZone.identifier
        )
        candidate.isManualEntry = !fromScan
        context.insert(candidate)
        do {
            try context.save()
        } catch {
            context.delete(candidate)
            throw error
        }
        return candidate
    }

    @MainActor
    static func discardIfUnused(_ candidate: EventCandidate, in context: ModelContext) {
        guard candidate.isManualEntry, candidate.savedEvent == nil else { return }
        context.delete(candidate)
        try? context.save()
    }
}
