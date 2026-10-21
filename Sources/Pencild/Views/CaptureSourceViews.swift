import SwiftUI
import SwiftData
import Photos

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
    let sources: [CaptureSource]
    let action: (CaptureSource) -> Void

    init(sources: [CaptureSource] = Array(CaptureSource.allCases), action: @escaping (CaptureSource) -> Void) {
        self.sources = sources
        self.action = action
    }

    private let columns = [
        GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(sources) { source in
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
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .top)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.pdSurfaceLow)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                if let feature = source.requiredFeature {
                    PDTierTag(tier: feature.requiredTier)
                        .padding(6)
                        .offset(x: 4, y: -8)
                }
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(source.title)
        .accessibilityHint(locked ? (source.requiredFeature?.upgradeReason ?? "") : source.accessibilityHint)
        .accessibilityIdentifier("capture.tile.\(source.id)")
    }
}

// MARK: - Shared screenshots card

/// The full-width screenshots entry point used by both Home and the Agenda capture sheet.
struct CaptureScreenshotsCard<Footer: View>: View {
    let action: () -> Void
    let isDisabled: Bool
    let footer: () -> Footer

    init(isDisabled: Bool = false, action: @escaping () -> Void, @ViewBuilder footer: @escaping () -> Footer) {
        self.action = action
        self.isDisabled = isDisabled
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: action) {
                HStack(alignment: .top, spacing: PDSpacing.md) {
                    Image(systemName: CaptureSource.screenshots.icon)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(CaptureSource.screenshots.tint)
                        .frame(width: 48, height: 48)
                        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceContainerHigh))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(CaptureSource.screenshots.title)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text(CaptureSource.screenshots.detail)
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(isDisabled)
            .accessibilityHint(CaptureSource.screenshots.accessibilityHint)

            footer()
        }
        .padding(PDSpacing.lg)
        .background(
            ZStack {
                Color.pdSurfaceContainer.opacity(0.9)
                Circle().fill(Color.pdPrimary.opacity(0.15)).frame(width: 192).blur(radius: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).offset(x: 48, y: -48)
                Circle().fill(Color.pdSecondaryContainer.opacity(0.2)).frame(width: 160).blur(radius: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).offset(x: -40, y: 40)
            }
            .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
    }
}

/// The stateful footer shared by the Home screenshots card and the Capture sheet.
struct CaptureScreenshotsFooter: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @Query private var scannedAssets: [ScannedAsset]
    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]
    @AppStorage(AutoDetectPreference.key) private var autoDetectPreferred = true

    let onScanAsset: (PHAsset) -> Void
    let onReview: () -> Void

    private var newScreenshots: [PHAsset] {
        let scanned = Set(scannedAssets.map(\.assetIdentifier))
        let unscanned = homeViewModel.recentScreenshots.filter { !scanned.contains($0.localIdentifier) }
        guard appState.isEntitled(to: .likelyEventTriage) else { return unscanned }
        return PhotoCandidateRanker.rank(unscanned, scannedIDs: scanned, likelyEventIDs: homeViewModel.likelyEventIDs)
    }

    private var needingReviewCount: Int {
        candidates.filter(\.needsReview).count
    }

    private var photosAuthorized: Bool {
        homeViewModel.photoAuthorizationStatus.access.isUsable
    }

    var body: some View {
        let entitledToAutoDetect = appState.isEntitled(to: .automaticScreenshotDetection)
        let autoDetect = entitledToAutoDetect && autoDetectPreferred

        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            if photosAuthorized && !newScreenshots.isEmpty {
                HStack(spacing: -8) {
                    ForEach(newScreenshots.prefix(3), id: \.localIdentifier) { asset in
                        Button { onScanAsset(asset) } label: {
                            AssetThumbnail(asset: asset, height: 56)
                                .frame(width: 48)
                                .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(scanViewModel.isProcessing)
                        .accessibilityLabel("Scan screenshot from \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                    }
                    if newScreenshots.count > 3 {
                        Text("+\(newScreenshots.count - 3)")
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdOnSurface)
                            .frame(width: 48, height: 56)
                            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(LinearGradient(colors: [.pdSurfaceBright, .pdSurfaceHighest], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    }
                    Spacer(minLength: 0)
                }
                .task(id: homeViewModel.recentScreenshots.map(\.localIdentifier)) {
                    if appState.isEntitled(to: .likelyEventTriage) {
                        homeViewModel.triageLikelyEvents(scannedIDs: Set(scannedAssets.map(\.assetIdentifier)))
                    }
                }
            }

            if autoDetect && !photosAuthorized {
                Text("Allow Photos access and Pencil\u{2019}d will check your newest screenshots whenever you open the app.")
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            HStack(spacing: 10) {
                if needingReviewCount > 0 {
                    Button(action: onReview) { reviewPill(needingReviewCount) }
                }
                Spacer(minLength: 0)
                if autoDetect {
                    Label("Screenshot detection enabled", systemImage: "checkmark")
                        .labelStyle(TrailingIconLabelStyle())
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdPrimary)
                } else if entitledToAutoDetect {
                    Label("Auto-detect is off", systemImage: "pause.circle")
                        .font(PDFont.labelMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                } else {
                    Button {
                        Task { await appState.present(.paywall(opening: .plus)) }
                    } label: {
                        Label("Auto-detect with Plus", systemImage: "lock.fill")
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdPrimary)
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint(HomeBrandCopy.plusScreenshotExplanation)
                }
            }
        }
    }

    private func reviewPill(_ count: Int) -> some View {
        HStack(spacing: PDSpacing.xs) {
            Circle().fill(Color.pdPrimary).frame(width: 6, height: 6)
            Text("\(count) Needing Review")
        }
        .font(PDFont.labelMD)
        .foregroundStyle(Color.pdPrimary)
        .padding(.horizontal, PDSpacing.sm)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.pdPrimaryContainer.opacity(0.2)))
        .frame(minHeight: 44)
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
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Environment(\.services) private var services

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    PDCloseButton(accessibilityLabel: "Close")
                }
                PDScreenIntro(
                    eyebrow: "Capture Sources",
                    title: "Create New Event",
                    subtitle: CaptureSheetCopy.welcomeBody
                )
                .padding(.top, 16)

                VStack(spacing: 10) {
                    CaptureScreenshotsCard(action: { choose(.screenshots) }) {
                        CaptureScreenshotsFooter(
                            onScanAsset: { asset in
                                Task {
                                    await scanViewModel.scanAsset(asset, modelContext: modelContext)
                                    await appState.handleScanOutcome(scanViewModel, services: services)
                                }
                            },
                            onReview: {
                                dismiss()
                                appState.selectedTab = .review
                            }
                        )
                    }

                    CaptureSourceGrid(sources: [.photoLibrary, .fileImport, .documentScanner, .manual]) { choose($0) }
                }
                .frame(maxWidth: 380)
                .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, PDSpacing.sm)
            .frame(maxWidth: .infinity)
        }
        .pdScreenBackground()
    }

    private func choose(_ source: CaptureSource) {
        if source == .manual {
            Task { await appState.startManualEntry(in: modelContext) }
        } else {
            Task { await appState.beginCapture(source) }
        }
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
