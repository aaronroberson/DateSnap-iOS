import SwiftUI
import SwiftData
import Photos

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
        Array(repeating: GridItem(.flexible(), spacing: PDSpacing.sm), count: horizontalSizeClass == .regular ? 5 : 3)
    }

    @State private var isSelecting = false
    @State private var selectedAssetIDs: Set<String> = []
    @State private var likelyOnly = false
    @State private var batchOverLimit: BatchOverLimit?
    @State private var showPlusPaywall = false

    /// Free plan only: scans left this month, or nil when scans are unlimited.
    private var remainingFreeScans: Int? {
        PlanLimits.limitsScans(services.subscription.entitlementSnapshot) ? services.scanUsage.remainingFreeScans() : nil
    }

    private var selectionExcess: Int {
        remainingFreeScans.map { max(0, selectedAssetIDs.count - $0) } ?? 0
    }

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
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    PDTopBar(title: "Recent screenshots") {
                        if !homeViewModel.recentScreenshots.isEmpty {
                            Button(isSelecting ? "Cancel" : "Select") {
                                isSelecting.toggle()
                                if !isSelecting { selectedAssetIDs.removeAll() }
                            }
                            .font(PDFont.labelLG)
                            .foregroundStyle(Color.pdPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("screenshots.select")
                        }
                    }
                    PDScreenIntro(eyebrow: "Screenshot triage", title: "Your screenshots", subtitle: "Choose the sources you want to scan on this device.")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: PDSpacing.xs) {
                            Button { likelyOnly = false } label: {
                                PDChip(text: "All · \(homeViewModel.recentScreenshots.count)", selected: !likelyOnly)
                            }
                            Button {
                                if appState.isEntitled(to: .likelyEventTriage) { likelyOnly = true }
                                else { Task { await appState.present(.paywall(opening: .plus)) } }
                            } label: {
                                PDChip(text: "Likely events", icon: appState.isEntitled(to: .likelyEventTriage) ? "sparkles" : "lock.fill", selected: likelyOnly && appState.isEntitled(to: .likelyEventTriage), paidTier: PremiumFeature.likelyEventTriage.requiredTier)
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
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)

                    if homeViewModel.isRefreshing && homeViewModel.recentScreenshots.isEmpty {
                        ProgressView().tint(Color.pdPrimary).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if visibleAssets.isEmpty {
                        PDCard {
                            VStack(spacing: PDSpacing.sm) {
                                PDIconTile(systemName: "photo.on.rectangle.angled", tint: .pdOnSurfaceVariant)
                                Text(likelyOnly ? "No likely events found" : "No screenshots found")
                                    .font(PDFont.headlineSM)
                                    .foregroundStyle(Color.pdOnSurface)
                                Text(likelyOnly ? "Open All to choose another screenshot for review." : homeViewModel.photoAuthorizationStatus == .limited
                                     ? "Pencil’d can only see the photos you shared. Choose more in iOS Settings, or use Choose from Photo Library."
                                     : "Take a screenshot of an event, then come back.")
                                    .font(PDFont.bodyMD)
                                    .foregroundStyle(Color.pdOnSurfaceVariant)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        LazyVGrid(columns: columns, spacing: PDSpacing.sm) {
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
            .pdScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                if isSelecting {
                    batchScanBar
                }
            }
            .batchAllowancePrompt(
                $batchOverLimit,
                deselectTitle: { "Deselect \($0.excess)" },
                onDeselect: { info in trimSelection(to: info.remaining) },
                onUpgrade: { showPlusPaywall = true },
                onDiscard: {
                    selectedAssetIDs.removeAll()
                    isSelecting = false
                }
            )
            .sheet(isPresented: $showPlusPaywall) {
                PaywallView(initialPlan: .plus)
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
                .foregroundStyle(selectedAssetIDs.contains(asset.localIdentifier) ? Color.pdPrimary : Color.white)
                .shadow(color: .black.opacity(0.6), radius: 3)
                .padding(6)
        } else if scannedIds.contains(asset.localIdentifier) {
            Label("Scanned", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.system(size: 18))
                .foregroundStyle(Color.pdSuccess)
                .padding(6)
                .accessibilityLabel("Already scanned")
        }
    }

    private var batchScanBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(selectedAssetIDs.count) selected")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                if selectionExcess > 0 {
                    Text("Deselect \(selectionExcess) more to stay within your free scans")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdWarning)
                } else if let remainingFreeScans {
                    Text("\(remainingFreeScans) free scan\(remainingFreeScans == 1 ? "" : "s") left this month")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            Spacer()
            Button {
                startBatchScan()
            } label: {
                HStack(spacing: 8) {
                    if appState.isBatchScanning {
                        ProgressView().tint(Color.pdOnPrimaryFixed)
                        Text("Scanning…")
                    } else {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("Scan Batch")
                        Image(systemName: "arrow.right")
                    }
                }
            }
            .buttonStyle(PDPrimaryButtonStyle())
            .disabled(selectedAssetIDs.isEmpty || appState.isBatchScanning)
        }
        .padding(.horizontal, PDSpacing.md)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.pdSurface.opacity(0.95))
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

    /// Keeps the earliest selected screenshots when the free allowance prompt asks the user
    /// to reduce the batch. The gallery order is the same order used to build `selectedAssets`.
    private func trimSelection(to count: Int) {
        selectedAssetIDs = Set(selectedAssets.prefix(max(0, count)).map(\.localIdentifier))
    }

    private func scan(_ asset: PHAsset) {
        dismiss()
        Task {
            await scanViewModel.scanAsset(asset, modelContext: modelContext)
            await appState.handleScanOutcome(scanViewModel, services: services)
        }
    }

    /// Starts the batch on the shared AppState so progress and the review sheet
    /// outlive this picker sheet.
    private func startBatchScan() {
        if let remainingFreeScans, selectionExcess > 0 {
            batchOverLimit = BatchOverLimit(selected: selectedAssetIDs.count, remaining: remainingFreeScans)
            return
        }
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
                    PDScreenIntro(eyebrow: "Batch scan", title: "Reading your sources", subtitle: "Each detected event will wait for your review.")
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
            RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceContainer.opacity(0.85))
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView().tint(Color.pdOnSurfaceVariant)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
        .overlay(RoundedRectangle(cornerRadius: PDRadius.card).stroke(Color.pdSurfaceHighest.opacity(0.6), lineWidth: 1))
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
        candidates.filter(\.needsReview)
    }
    private var highConfidence: [EventCandidate] { pending.filter { $0.confidenceTier == .high } }
    private var visibleCandidates: [EventCandidate] { highConfidenceOnly ? highConfidence : pending }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDScreenIntro(eyebrow: "Review queue", title: "Needs review", subtitle: "Nothing is added to your calendar until you confirm it.")
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
                    } else if horizontalSizeClass == .regular {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: PDSpacing.md), GridItem(.flexible(), spacing: PDSpacing.md)],
                            alignment: .leading,
                            spacing: PDSpacing.md
                        ) {
                            queueRows
                        }
                    } else {
                        queueRows
                    }
                }
                .frame(maxWidth: horizontalSizeClass == .regular ? 1040 : .infinity)
                .padding(.horizontal, horizontalSizeClass == .regular ? 28 : PDSpacing.md)
                .padding(.top, PDSpacing.md)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity)
            }
            .pdScreenBackground()
            .safeAreaInset(edge: .bottom) {
                if !pending.isEmpty {
                    VStack(spacing: PDSpacing.xs) {
                        Button {
                            presentHighConfidenceReview()
                        } label: {
                            Label("Confirm all suggested (\(highConfidence.count))", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(PDPrimaryButtonStyle())
                        .disabled(highConfidence.isEmpty)
                        .accessibilityIdentifier("review.batch.highConfidence")
                        Text("Choose destinations and confirm each event before saving.")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: horizontalSizeClass == .regular ? 560 : .infinity)
                    .padding(PDSpacing.md)
                    .padding(.bottom, horizontalSizeClass == .regular ? 0 : 72)
                    .frame(maxWidth: .infinity)
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

    private var queueRows: some View {
        ForEach(visibleCandidates) { candidate in
            ReviewQueueRow(candidate: candidate, onReview: { Task { await appState.review(candidate) } }, onDiscard: {
                candidateToDiscard = candidate
                showDiscardConfirmation = true
            })
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
                .buttonStyle(PDSecondaryButtonStyle())
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
                    PDStatusBadge(text: "\(Int((candidate.confidenceScore * 100).rounded()))% · \(candidate.confidenceTier.label)", icon: candidate.confidenceTier.iconName, tone: candidate.confidenceTier == .high ? .success : .warning)
                    if candidate.savedEvent?.status == .draft {
                        PDStatusBadge(text: "Draft", icon: "bookmark.fill", tone: .neutral)
                    }
                }
                HStack(spacing: PDSpacing.sm) {
                    Button(action: onReview) { Label("Review", systemImage: "pencil") }
                        .buttonStyle(PDPrimaryButtonStyle())
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
