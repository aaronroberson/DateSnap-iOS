import SwiftUI
import SwiftData
import Photos

// MARK: - Scan Outcome Routing
extension AppState {
    /// Presents a modal, first dismissing any sheet already on screen.
    func present(_ modal: AppModalScreen) async {
        if activeModal != nil {
            activeModal = nil
            try? await Task.sleep(for: .milliseconds(400))
        }
        activeModal = modal
    }

    /// Routes a finished scan to review, the no-dates recovery screen, or an error toast.
    func handleScanOutcome(_ scan: ScanViewModel) async {
        switch scan.stage {
        case .complete(let candidates):
            rememberSourceImage(scan.currentProcessingImage, for: candidates)
            guard let first = candidates.first else { return }
            await present(.eventReviewEdit(first.toPencildEvent()))
            if candidates.count > 1 {
                showToast("\(candidates.count - 1) more event\(candidates.count == 2 ? "" : "s") waiting in Review")
            }
        case .noDatesFound(let rawText):
            lastScanRawText = rawText
            lastScanImage = scan.currentProcessingImage
            await present(.noDatesFound)
        case .alreadySaved(let count):
            activeModal = nil
            showToast(count == 1 ? "Already saved — find it in History" : "All \(count) events are already saved")
            openHistory()
        case .failed(let message):
            activeModal = nil
            showToast(message)
        default:
            break
        }
    }
}

// MARK: - Scan Progress Overlay
struct ScanProgressOverlay: View {
    @ObservedObject var scan: ScanViewModel

    private var step: Int {
        switch scan.stage {
        case .fetchingImage: return 0
        case .processingOCR: return 1
        case .extractingEvents: return 2
        case .interpreting: return 3
        default: return 0
        }
    }

    var body: some View {
        if scan.isProcessing {
            ZStack {
                Color.pdSurface.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: PDSpacing.lg) {
                        HStack {
                            PDEyebrow(text: "ON-DEVICE SCAN")
                            Spacer()
                            Button(scan.isCancelling ? "Canceling…" : "Cancel") { scan.cancelScan() }
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdPrimary)
                                .frame(minWidth: 44, minHeight: 44)
                                .disabled(scan.isCancelling)
                                .accessibilityIdentifier("scan.cancel")
                        }
                        PDScreenIntro(
                            eyebrow: "SCANNED. REVIEWED. PENCIL'D.",
                            title: scan.isCancelling ? "Stopping this scan" : "Finding your event",
                            subtitle: "Nothing is added to your calendar until you review and confirm it."
                        )
                        if let image = scan.currentProcessingImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 240)
                                .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                                .accessibilityLabel("Source being scanned")
                        }
                        if let detail = scan.progressDetail {
                            PDStatusBadge(text: detail, icon: "doc.on.doc", tone: .info)
                        }
                        PDCard {
                            VStack(spacing: PDSpacing.md) {
                                PDScanStepRow(title: "Load source", icon: "photo", complete: step > 0, active: step == 0)
                                PDScanStepRow(title: "Read text on device", icon: "text.viewfinder", complete: step > 1, active: step == 1)
                                PDScanStepRow(title: "Find dates and places", icon: "calendar.badge.magnifyingglass", complete: step > 2, active: step == 2)
                                if scan.stage == .interpreting {
                                    PDScanStepRow(title: "Interpret event details", icon: "sparkles", complete: false, active: true)
                                }
                            }
                        }
                        if scan.stage == .interpreting && !scan.isCancelling {
                            Button("Skip — use standard result") { scan.skipInterpretation() }
                                .buttonStyle(DSSecondaryButtonStyle())
                                .accessibilityHint("Stops Apple Intelligence and shows the rules-based result")
                                .accessibilityIdentifier("scan.skipInterpretation")
                        }
                        Label("Private, on-device processing", systemImage: "lock.shield.fill")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    .padding(PDSpacing.md)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

private struct PDScanStepRow: View {
    let title: String
    let icon: String
    let complete: Bool
    let active: Bool

    var body: some View {
        HStack(spacing: PDSpacing.sm) {
            PDIconTile(systemName: complete ? "checkmark" : icon, tint: complete ? .pdSuccess : (active ? .pdPrimary : .pdOnSurfaceVariant))
            Text(title)
                .font(PDFont.bodyMD)
                .foregroundStyle(active || complete ? Color.pdOnSurface : Color.pdOnSurfaceVariant)
            Spacer(minLength: 0)
            if active {
                ProgressView().tint(Color.pdPrimary)
            } else if complete {
                Text("Done").font(PDFont.labelMD).foregroundStyle(Color.pdSuccess)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(complete ? "Complete" : (active ? "In progress" : "Waiting"))
    }
}

// MARK: - Recent Screenshots Gallery
struct RecentScreenshotsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @Query private var scannedAssets: [ScannedAsset]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: horizontalSizeClass == .regular ? 5 : 3)
    }

    @State private var isSelecting = false
    @State private var selectedAssetIDs: Set<String> = []
    @State private var likelyOnly = false

    private var scannedIds: Set<String> { Set(scannedAssets.map(\.assetIdentifier)) }

    private var selectedAssets: [PHAsset] {
        homeViewModel.recentScreenshots.filter { selectedAssetIDs.contains($0.localIdentifier) }
    }

    private var visibleAssets: [PHAsset] {
        let assets = homeViewModel.recentScreenshots
        guard appState.isEntitled(to: .likelyEventTriage) else { return assets }
        let ranked = PhotoCandidateRanker.rank(assets, scannedIDs: scannedIds, likelyEventIDs: homeViewModel.likelyEventIDs)
        return likelyOnly ? ranked.filter { homeViewModel.likelyEventIDs.contains($0.localIdentifier) } : ranked
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PDScreenIntro(eyebrow: "SCREENSHOT TRIAGE", title: "Your screenshots", subtitle: "Choose the sources you want to scan on this device.")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PDSpacing.xs) {
                            Button { likelyOnly = false } label: {
                                PDChip(text: "All · \(homeViewModel.recentScreenshots.count)", selected: !likelyOnly)
                            }
                            Button {
                                if appState.isEntitled(to: .likelyEventTriage) { likelyOnly = true }
                                else { Task { await appState.present(.plusPaywall) } }
                            } label: {
                                PDChip(text: "Likely events", icon: appState.isEntitled(to: .likelyEventTriage) ? "sparkles" : "lock.fill", selected: likelyOnly && appState.isEntitled(to: .likelyEventTriage))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if isSelecting && !visibleAssets.isEmpty {
                        Button(selectedAssetIDs.isSuperset(of: Set(visibleAssets.map(\.localIdentifier))) ? "Deselect all" : "Select all") {
                            let visibleIDs = Set(visibleAssets.map(\.localIdentifier))
                            if selectedAssetIDs.isSuperset(of: visibleIDs) { selectedAssetIDs.subtract(visibleIDs) }
                            else { selectedAssetIDs.formUnion(visibleIDs) }
                        }
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("screenshots.selectAll")
                    }
                    Text(isSelecting
                         ? "Tap screenshots to add them to the batch. Each event keeps its own calendar and reminders."
                         : "Pick a screenshot of a flyer, invite, or ticket. Text is read on this device only.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)

                    if homeViewModel.isRefreshing && homeViewModel.recentScreenshots.isEmpty {
                        ProgressView().tint(Color.dsPrimary).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if visibleAssets.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.dsMutedForeground)
                            Text(likelyOnly ? "No likely events found" : "No screenshots found")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Text(likelyOnly ? "Open All to choose another screenshot for review." : homeViewModel.photoAuthorizationStatus == .limited
                                 ? "Pencil'd can only see the photos you shared. Choose more in iOS Settings, or use Choose from Photo Library."
                                 : "Take a screenshot of an event, then come back.")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(visibleAssets, id: \.localIdentifier) { asset in
                                Button {
                                    if isSelecting {
                                        toggleSelection(asset)
                                    } else {
                                        scan(asset)
                                    }
                                } label: {
                                    AssetThumbnail(asset: asset)
                                        .overlay(alignment: .topTrailing) {
                                            badge(for: asset)
                                        }
                                }
                                .accessibilityLabel("Screenshot from \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                                .accessibilityAddTraits(isSelecting && selectedAssetIDs.contains(asset.localIdentifier) ? .isSelected : [])
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: 1040)
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : PDSpacing.md)
                .padding(.vertical, PDSpacing.md)
                .padding(.bottom, isSelecting ? 120 : 0)
                .frame(maxWidth: .infinity)
            }
            .dsScreenBackground()
            .navigationTitle("Recent Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSelecting ? "Cancel" : "Close") {
                        if isSelecting {
                            isSelecting = false
                            selectedAssetIDs.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !homeViewModel.recentScreenshots.isEmpty {
                        Button(isSelecting ? "Done" : "Select") {
                            isSelecting.toggle()
                            if !isSelecting { selectedAssetIDs.removeAll() }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    batchScanBar
                }
            }
            .task { homeViewModel.loadRecentScreenshots(limit: 30) }
            .onChange(of: homeViewModel.recentScreenshots.map(\.localIdentifier)) { _, _ in
                if appState.isEntitled(to: .likelyEventTriage) {
                    homeViewModel.triageLikelyEvents(scannedIDs: scannedIds)
                }
            }
        }
    }

    @ViewBuilder
    private func badge(for asset: PHAsset) -> some View {
        if isSelecting {
            Image(systemName: selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(selectedAssetIDs.contains(asset.localIdentifier) ? Color.dsPrimary : Color.white)
                .shadow(color: .black.opacity(0.6), radius: 3)
                .padding(6)
        } else if scannedIds.contains(asset.localIdentifier) {
            Label("Scanned", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: 18))
                .foregroundStyle(Color.dsSuccess)
                .padding(6)
                .accessibilityLabel("Already scanned")
        }
    }

    private var batchScanBar: some View {
        HStack(spacing: 12) {
            Text("\(selectedAssetIDs.count) selected")
                .font(DSTypography.bodyCompact())
                .foregroundStyle(Color.dsForeground)
            Spacer()
            Button {
                startBatchScan()
            } label: {
                HStack(spacing: 8) {
                    if appState.isBatchScanning {
                        ProgressView().tint(Color.dsPrimaryForeground)
                        Text("Scanning…")
                    } else {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Scan Batch")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(DSPrimaryButtonStyle())
            .disabled(selectedAssetIDs.isEmpty || appState.isBatchScanning)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.dsBackground.opacity(0.95))
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func toggleSelection(_ asset: PHAsset) {
        if selectedAssetIDs.contains(asset.localIdentifier) {
            selectedAssetIDs.remove(asset.localIdentifier)
        } else {
            selectedAssetIDs.insert(asset.localIdentifier)
        }
    }

    private func scan(_ asset: PHAsset) {
        dismiss()
        Task {
            await scanViewModel.scanAsset(asset, modelContext: modelContext)
            await appState.handleScanOutcome(scanViewModel)
        }
    }

    /// Starts the batch on the shared AppState so progress and the review sheet
    /// outlive this picker sheet.
    private func startBatchScan() {
        let sources = selectedAssets.map { BatchScanSource.asset($0) }
        isSelecting = false
        selectedAssetIDs.removeAll()
        dismiss()
        Task { @MainActor in
            await appState.startBatchScan(
                sources: sources,
                services: services,
                modelContext: modelContext
            )
        }
    }
}

// MARK: - Batch Scan Progress Overlay
/// Sequential progress for a multi-screenshot scan ("Screenshot 2 of 5"), shown while
/// a batch started from any screen is still running.
struct BatchScanProgressOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.isBatchScanning, let scanner = appState.activeBatchScan {
            BatchScanProgressContent(scanner: scanner)
        }
    }
}

private struct BatchScanProgressContent: View {
    @ObservedObject var scanner: BatchScanViewModel

    var body: some View {
        ZStack {
            Color.pdSurface.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDScreenIntro(eyebrow: "BATCH SCAN", title: "Reading your sources", subtitle: "Each detected event will wait for your review.")
                    HStack {
                        ProgressView().tint(Color.pdPrimary)
                        Text(scanner.currentLabel.isEmpty ? "Preparing…" : scanner.currentLabel)
                            .font(PDFont.bodyLG)
                            .foregroundStyle(Color.pdOnSurface)
                        Spacer(minLength: 0)
                    }
                    Text("\(scanner.items.filter(\.isResolved).count) of \(scanner.items.count) sources processed")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                    ForEach(scanner.items) { item in
                        BatchScanProgressRow(item: item)
                    }
                    Label("Private, on-device processing", systemImage: "lock.shield.fill")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                .padding(PDSpacing.md)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct BatchScanProgressRow: View {
    @ObservedObject var item: BatchScanItem

    private var status: (text: String, icon: String, tone: PDStatusBadge.Tone) {
        switch item.stage {
        case .pending: return ("Waiting", "clock", .neutral)
        case .scanning: return ("Scanning", "text.viewfinder", .info)
        case .found(let count): return ("\(count) event\(count == 1 ? "" : "s") found", "checkmark.circle.fill", .success)
        case .noDates: return ("No dates found", "calendar.badge.exclamationmark", .warning)
        case .alreadySaved(let count): return ("\(count) already saved", "calendar.badge.checkmark", .success)
        case .failed(let message): return (message, "exclamationmark.triangle.fill", .error)
        }
    }

    var body: some View {
        PDCard {
            HStack(alignment: .top, spacing: PDSpacing.sm) {
                if let image = item.image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: 56, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
                        .accessibilityHidden(true)
                } else {
                    PDIconTile(systemName: "photo", tint: .pdOnSurfaceVariant)
                }
                VStack(alignment: .leading, spacing: PDSpacing.xs) {
                    Text(item.label).font(PDFont.headlineSM).foregroundStyle(Color.pdOnSurface)
                    PDStatusBadge(text: status.text, icon: status.icon, tone: status.tone)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Asset Thumbnail
struct AssetThumbnail: View {
    @Environment(\.services) private var services
    let asset: PHAsset
    var height: CGFloat = 150
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(Color.dsCard)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView().tint(Color.dsMutedForeground)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dsBorder, lineWidth: 1))
        .task(id: asset.localIdentifier) {
            image = try? await services.photoLibrary.fetchImage(for: asset, targetSize: CGSize(width: 360, height: 640))
        }
    }
}

// MARK: - Review Queue (Review tab)
/// Real unsaved scans and drafts. Bulk review always opens the confirmation sheet.
struct ReviewQueueView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.services) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]
    @State private var highConfidenceOnly = false
    @State private var candidateToDiscard: EventCandidate?
    @State private var showDiscardConfirmation = false

    private var pending: [EventCandidate] {
        candidates.filter { $0.savedEvent == nil || $0.savedEvent?.status == .draft }
    }
    private var highConfidence: [EventCandidate] { pending.filter { $0.confidenceTier == .high } }
    private var visibleCandidates: [EventCandidate] { highConfidenceOnly ? highConfidence : pending }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDScreenIntro(eyebrow: "REVIEW QUEUE", title: "Needs review", subtitle: "Nothing is added to your calendar until you confirm it.")
                    PDStatusBadge(text: "\(pending.count) pending review", icon: "tray.full.fill", tone: pending.isEmpty ? .neutral : .warning)
                    PDCard {
                        VStack(alignment: .leading, spacing: PDSpacing.xs) {
                            Label("You stay in control", systemImage: "hand.raised.fill")
                                .font(PDFont.labelLG)
                                .foregroundStyle(Color.pdPrimary)
                            Text("Check the source, date, and destination. High confidence still waits for your confirmation.")
                                .font(PDFont.bodyMD)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PDSpacing.xs) {
                            Button { highConfidenceOnly = false } label: {
                                PDChip(text: "All · \(pending.count)", selected: !highConfidenceOnly)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("review.filter.all")
                            Button { highConfidenceOnly = true } label: {
                                PDChip(text: "High confidence · \(highConfidence.count)", icon: "checkmark.seal", selected: highConfidenceOnly)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("review.filter.high")
                        }
                    }
                    if visibleCandidates.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleCandidates) { candidate in
                            ReviewQueueRow(candidate: candidate, onReview: { appState.review(candidate) }, onDiscard: {
                                candidateToDiscard = candidate
                                showDiscardConfirmation = true
                            })
                        }
                    }
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 1040 : .infinity)
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : PDSpacing.md)
                .padding(.top, PDSpacing.md)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity)
            }
            .dsScreenBackground()
            .safeAreaInset(edge: .bottom) {
                if !pending.isEmpty {
                    VStack(spacing: PDSpacing.xs) {
                        Button {
                            presentHighConfidenceReview()
                        } label: {
                            Label("Review high confidence (\(highConfidence.count))", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(DSPrimaryButtonStyle())
                        .disabled(highConfidence.isEmpty)
                        .accessibilityIdentifier("review.batch.highConfidence")
                        Text("Choose destinations and confirm each event before saving.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .padding(PDSpacing.md)
                    .padding(.bottom, horizontalSizeClass == .regular ? 0 : 72)
                    .background(Color.pdSurface)
                }
            }
            .alert("Discard this scan?", isPresented: $showDiscardConfirmation, presenting: candidateToDiscard) { candidate in
                Button("Discard", role: .destructive) {
                    let review = EventReviewViewModel(candidate: candidate, services: services)
                    let result = review.discard(modelContext: modelContext)
                    switch result {
                    case .success, .partial: appState.showToast("Scan discarded")
                    case .failure(let failure): appState.showToast(failure.message)
                    }
                    candidateToDiscard = nil
                }
                Button("Keep scan", role: .cancel) { candidateToDiscard = nil }
            } message: { candidate in
                Text("Remove \(candidate.title) from the review queue? This does not change your calendar.")
            }
        }
    }

    private var emptyState: some View {
        PDCard {
            VStack(spacing: PDSpacing.sm) {
                PDIconTile(systemName: "checkmark.seal", tint: .pdSuccess)
                Text(pending.isEmpty ? "All caught up" : "No high-confidence scans")
                    .font(PDFont.headlineSM)
                    .foregroundStyle(Color.pdOnSurface)
                Text(pending.isEmpty ? "Scan a screenshot or flyer from Home. Detected events will wait here for your review." : "Your other scans still need a closer look. Open All to review them.")
                    .font(PDFont.bodyMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.center)
                Button(pending.isEmpty ? "Go to scanner" : "Show all scans") {
                    if pending.isEmpty { appState.selectedTab = .home } else { highConfidenceOnly = false }
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func presentHighConfidenceReview() {
        let events = highConfidence.map { candidate in
            BatchEventItem(candidate: candidate, screenshotID: UUID(),
                           screenshotLabel: candidate.scannedAsset.map { "Scanned " + $0.scannedAt.formatted(date: .abbreviated, time: .shortened) } ?? "Review queue",
                           screenshotImage: appState.sourceImages[candidate.id], services: services)
        }
        guard !events.isEmpty else { return }
        Task { await appState.presentBatchReview(BatchReviewSession(events: events)) }
    }
}

private struct ReviewQueueRow: View {
    let candidate: EventCandidate
    let onReview: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        let event = candidate.toPencildEvent()
        PDCard {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top, spacing: PDSpacing.sm) {
                    PDScanSourceThumbnail(candidate: candidate)
                        .frame(width: 64, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: PDRadius.tile))
                    VStack(alignment: .leading, spacing: PDSpacing.xs) {
                        Text(candidate.title)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Label(candidate.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        Label(candidate.isAllDay ? "All day" : event.timeWindow, systemImage: "clock")
                        if let location = candidate.location ?? candidate.venueName, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                        }
                    }
                    .font(PDFont.bodySM)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    Spacer(minLength: 0)
                }
                HStack {
                    DSConfidencePill(score: Int((candidate.confidenceScore * 100).rounded()), label: candidate.confidenceTier.label)
                    if candidate.savedEvent?.status == .draft {
                        PDStatusBadge(text: "Draft", icon: "bookmark.fill", tone: .neutral)
                    }
                }
                HStack(spacing: PDSpacing.sm) {
                    Button(action: onReview) { Label("Review", systemImage: "pencil") }
                        .buttonStyle(DSPrimaryButtonStyle())
                        .accessibilityIdentifier("review.event.\(candidate.id)")
                    if candidate.savedEvent == nil {
                        Button(action: onDiscard) {
                            Image(systemName: "xmark")
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Discard \(candidate.title)")
                    }
                }
            }
        }
    }
}
