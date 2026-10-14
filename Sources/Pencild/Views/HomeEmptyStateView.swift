import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

enum HomeBrandCopy {
    static let captureHeading = "Turn Schedules Into Events"
    static let captureSubtitle = "Scan flyers, import syllabi, or let Pencil'd Plus spot events in your new screenshots."
    static let photoLibraryPermissionMessage = "Pencil'd needs Photo Library access to find your recent screenshots. You can still pick individual photos without it."
    static let premiumFileImportAccessibilityHint = "Requires Pencil'd Premium"
    static let plusScreenshotExplanation = "Pencil'd Plus checks new screenshots on your device and highlights likely events. Nothing is saved until you review it."
    static let privacyHeading = "Private & On-Device Intelligence"
    static let privacyBody = "Your photos, screenshots, and documents are processed on this device. Review every detected event before saving."
}

/// Capture home (Stitch "Home Screen"): pick where the next event comes from.
/// Every source routes into the existing scan pipeline and review flow.
struct HomeEmptyStateView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var scannedAssets: [ScannedAsset]
    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    /// True while the picker is reopened so the user can deselect items over the free allowance;
    /// the edited selection is processed when the picker closes.
    @State private var isTrimmingPhotoSelection = false
    @State private var batchOverLimit: BatchOverLimit?
    @State private var pendingBatch: PendingBatch?
    @State private var showPhotoPicker: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showPhotoAccessAlert: Bool = false
    @State private var showDocumentCamera: Bool = false
    @AppStorage(AutoDetectPreference.key) private var autoDetectPreferred = true

    /// Screenshots the library observer has seen that Pencil'd has not scanned yet.
    private var newScreenshots: [PHAsset] {
        let scanned = Set(scannedAssets.map(\.assetIdentifier))
        let unscanned = homeViewModel.recentScreenshots.filter { !scanned.contains($0.localIdentifier) }
        guard appState.isEntitled(to: .likelyEventTriage) else { return unscanned }
        return PhotoCandidateRanker.rank(unscanned, scannedIDs: scanned, likelyEventIDs: homeViewModel.likelyEventIDs)
    }

    /// Candidates waiting on the user, same definition as the Review tab.
    private var needingReviewCount: Int {
        candidates.filter { $0.savedEvent == nil || $0.savedEvent?.status == .draft }.count
    }

    private var photosAuthorized: Bool {
        homeViewModel.photoAuthorizationStatus == .authorized || homeViewModel.photoAuthorizationStatus == .limited
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                captureContent
            }
            .background(Color.pdSurface.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.2), value: scanViewModel.isProcessing)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared())
            .sheet(isPresented: $showDocumentCamera) {
                DocumentCameraScanner(
                    onScan: { images in
                        showDocumentCamera = false
                        requestBatch(.cameraPages(images))
                    },
                    onCancel: { showDocumentCamera = false },
                    onError: { error in
                        showDocumentCamera = false
                        appState.showToast("Could not scan document: \(error.localizedDescription)")
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty, !isTrimmingPhotoSelection else { return }
                selectedPhotoItems = []
                handlePickedPhotos(items)
            }
            .onChange(of: showPhotoPicker) { _, isShown in
                guard !isShown, isTrimmingPhotoSelection else { return }
                isTrimmingPhotoSelection = false
                let items = selectedPhotoItems
                selectedPhotoItems = []
                handlePickedPhotos(items)
            }
            .batchAllowancePrompt(
                $batchOverLimit,
                deselectTitle: { info in
                    if case .cameraPages = pendingBatch { return "Scan First \(info.remaining) Page\(info.remaining == 1 ? "" : "s")" }
                    return "Deselect \(info.excess)"
                },
                onDeselect: { info in trimPendingBatch(to: info.remaining) },
                onUpgrade: { Task { await appState.present(.plusPaywall) } },
                onDiscard: { pendingBatch = nil }
            )
            .onChange(of: appState.subscriptionTier) { _, tier in
                // Upgraded from the prompt: run the batch the user had chosen.
                guard tier != .starter, let pending = pendingBatch else { return }
                pendingBatch = nil
                run(pending)
            }
            .onChange(of: appState.requestPhotoPicker) { _, requested in
                if requested {
                    appState.requestPhotoPicker = false
                    showPhotoPicker = true
                }
            }
            .onChange(of: appState.requestFileImporter) { _, requested in
                if requested {
                    appState.requestFileImporter = false
                    openFileImport()
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    runDocumentScan(at: url)
                case .failure(let error):
                    appState.showToast(error.localizedDescription)
                }
            }
            .alert("Allow Photo Access", isPresented: $showPhotoAccessAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
                Button("Choose a Photo Instead") { showPhotoPicker = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(HomeBrandCopy.photoLibraryPermissionMessage)
            }
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        if horizontalSizeClass == .regular {
            VStack(alignment: .leading, spacing: 18) {
                topBar
                titleBlock
                scanAllowanceBanner
                recentScreenshotsCard
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                    photoLibraryCard
                    fileImportCard
                    documentCameraCard
                    createEventCard
                    sampleFlyerCard
                }
                privacyFooter
                Color.clear.frame(height: 90)
            }
            .frame(maxWidth: 1120)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                titleBlock
                scanAllowanceBanner
                recentScreenshotsCard
                photoLibraryCard
                fileImportCard
                createEventCard
                sampleFlyerCard
                privacyFooter
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = .settings }
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pdOnPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.pdPrimary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Profile and settings")
        }
        .frame(height: 52)
    }

    private var titleBlock: some View {
        VStack(spacing: PDSpacing.sm) {
            Text(HomeBrandCopy.captureHeading)
                .font(PDFont.headlineLG)
                .foregroundStyle(LinearGradient(colors: [.pdOrange, .pdCoral, .pdLavender], startPoint: .leading, endPoint: .trailing))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Image("PencildMark")
                .resizable()
                .scaledToFit()
                .frame(width: 144)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .accessibilityHidden(true)
            Text(HomeBrandCopy.captureSubtitle)
                .font(PDFont.bodyMD)
                .foregroundStyle(Color.pdOnSurfaceVariant)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, PDSpacing.sm)
        .padding(.bottom, PDSpacing.xs)
    }

    // MARK: - Source cards

    private var recentScreenshotsCard: some View {
        let entitledToAutoDetect = appState.isEntitled(to: .automaticScreenshotDetection)
        let autoDetect = entitledToAutoDetect && autoDetectPreferred
        return VStack(alignment: .leading, spacing: 14) {
            Button(action: scanRecentScreenshots) {
                HStack(alignment: .top, spacing: PDSpacing.md) {
                    sourceIcon("rectangle.dashed.badge.record", tint: .pdPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent screenshots")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Find event flyers, tickets, and invitations in the screenshots you choose.")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PressScaleButtonStyle())
            .disabled(scanViewModel.isProcessing)
            .accessibilityHint("Shows your recent screenshots to scan")

            if photosAuthorized && !newScreenshots.isEmpty {
                HStack(spacing: -8) {
                    ForEach(newScreenshots.prefix(3), id: \.localIdentifier) { asset in
                        Button {
                            runScan { await scanViewModel.scanAsset(asset, modelContext: modelContext) }
                        } label: {
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
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = .review }
                    } label: {
                        reviewPill(needingReviewCount)
                    }
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
                        Task { await appState.present(.plusPaywall) }
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
        .padding(PDSpacing.lg)
        .background(
            ZStack {
                Color.pdSurfaceContainer.opacity(0.9)
                Circle().fill(Color.pdPrimary.opacity(0.15)).frame(width: 192).blur(radius: 40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).offset(x: 48, y: -48)
                Circle().fill(Color.pdSecondaryContainer.opacity(0.2)).frame(width: 160).blur(radius: 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading).offset(x: -40, y: 40)
                SignatureRibbons().opacity(0.4)
            }
            .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
    }

    /// Free plan only: how many of this month's scans remain, with a path to Plus.
    @ViewBuilder
    private var scanAllowanceBanner: some View {
        if PlanLimits.limitsScans(services.subscription.entitlementSnapshot) {
            let remaining = services.scanUsage.remainingFreeScans()
            HStack(spacing: PDSpacing.sm) {
                Image(systemName: remaining == 0 ? "exclamationmark.circle.fill" : "sparkle")
                    .foregroundStyle(remaining == 0 ? Color.pdWarning : Color.pdPrimary)
                    .accessibilityHidden(true)
                Text(remaining == 0
                     ? "No free scans left this month"
                     : "\(remaining) of \(PlanLimits.freeScansPerMonth) free scans left this month")
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdOnSurface)
                Spacer(minLength: PDSpacing.sm)
                Button("Upgrade") { Task { await appState.present(.plusPaywall) } }
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdPrimary)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, PDSpacing.md)
            .padding(.vertical, PDSpacing.xs)
            .background(Color.pdSurfaceContainer.opacity(0.85), in: RoundedRectangle(cornerRadius: PDRadius.card))
            .accessibilityElement(children: .combine)
        }
    }

    private var photoLibraryCard: some View {
        sourceRow(
            icon: "photo.on.rectangle",
            tint: .pdSecondary,
            title: "Photo library",
            detail: "Choose from your saved photos, whiteboards, or custom albums.",
            chips: ["Albums", "Camera Roll", "Favorites"]
        ) {
            showPhotoPicker = true
        }
    }

    private var fileImportCard: some View {
        let entitled = appState.isEntitled(to: .documentImport)
        return sourceRow(
            icon: entitled ? "doc" : "lock.fill",
            tint: .pdTertiary,
            title: "PDF or file import",
            detail: "Multi-page conference schedules, syllabi, flight itineraries & documents.",
            chips: entitled ? [".PDF", "Images", "iCloud Drive"] : [".PDF", "Images", "Premium"],
            hint: entitled ? "Scan a PDF or image from Files" : HomeBrandCopy.premiumFileImportAccessibilityHint
        ) {
            openFileImport()
        }
    }

    private var documentCameraCard: some View {
        sourceRow(
            icon: "doc.viewfinder",
            tint: .pdSecondary,
            title: "Scan a paper flyer",
            detail: "Capture and straighten multi-page paper documents, then review detected events before saving.",
            chips: ["Camera", "Multi-page", "On-device"],
            hint: "Opens the document camera"
        ) {
            guard VNDocumentCameraViewController.isSupported else {
                appState.showToast("Document scanning needs a device with a camera.")
                return
            }
            showDocumentCamera = true
        }
    }

    private var createEventCard: some View {
        Button {
            if let url = URL(string: "calshow://") { openURL(url) }
        } label: {
            HStack(spacing: PDSpacing.md) {
                sourceIcon("calendar.badge.plus", tint: .pdPrimary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create an event")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Opens the Calendar app for manually creating events and notifications.")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.pdPrimary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.pdSurfaceHighest))
            }
            .padding(PDSpacing.lg)
            .cardBackground()
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityHint("Opens the Calendar app")
    }

    private var sampleFlyerCard: some View {
        Button {
            runScan { await scanViewModel.scanSampleFlyer(modelContext: modelContext) }
        } label: {
            VStack(alignment: .leading, spacing: PDSpacing.sm) {
                HStack(alignment: .top, spacing: PDSpacing.md) {
                    sourceIcon("sparkles", tint: .pdPrimary, fill: .pdSurfaceContainer)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try sample flyer")
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Run the on-device scanner on a clearly labeled sample, then review what it finds.")
                            .font(PDFont.bodyMD)
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                Text("Interactive demo")
                    .font(PDFont.labelSM)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(Color.pdSecondary)
                    .padding(.horizontal, PDSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.pdSecondaryContainer.opacity(0.4)))
                HStack(spacing: PDSpacing.sm) {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.pdPrimary)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.pdSurfaceContainerHigh))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Built-in sample flyer")
                            .font(PDFont.labelMD)
                            .foregroundStyle(Color.pdOnSurface)
                        Label("No photo access needed", systemImage: "calendar")
                            .font(PDFont.bodySM)
                            .foregroundStyle(Color.pdPrimary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.pdPrimary)
                }
                .padding(PDSpacing.sm)
                .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.8)))
            }
            .padding(PDSpacing.lg)
            .background(
                ZStack {
                    Color.pdSurfaceLow
                    Circle().fill(Color.pdSecondaryContainer.opacity(0.2)).frame(width: 96).blur(radius: 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).offset(x: 24, y: 24)
                }
                .clipShape(RoundedRectangle(cornerRadius: PDRadius.card))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(scanViewModel.isProcessing)
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: PDSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.pdPrimary)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.pdSurfaceHighest))
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(HomeBrandCopy.privacyHeading)
                    .font(PDFont.jakarta(12, .medium, relativeTo: .footnote))
                    .foregroundStyle(Color.pdOnSurface)
                Text(HomeBrandCopy.privacyBody)
                    .font(PDFont.labelMD)
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .padding(PDSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(Color.pdSurfaceLowest.opacity(0.6)))
        .padding(.top, PDSpacing.md)
    }

    // MARK: - Card building blocks

    private func sourceIcon(_ systemName: String, tint: Color, fill: Color = .pdSurfaceContainerHigh) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(RoundedRectangle(cornerRadius: PDRadius.card).fill(fill))
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

    private func sourceRow(
        icon: String,
        tint: Color,
        title: String,
        detail: String,
        chips: [String],
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: PDSpacing.md) {
                sourceIcon(icon, tint: tint)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(PDFont.headlineSM)
                            .foregroundStyle(Color.pdOnSurface)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                    }
                    Text(detail)
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: PDSpacing.xs) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(PDFont.labelSM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .padding(.horizontal, PDSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.pdSurfaceHighest))
                        }
                    }
                    .padding(.top, PDSpacing.xs)
                }
            }
            .padding(PDSpacing.lg)
            .cardBackground()
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(scanViewModel.isProcessing)
        .accessibilityHint(hint ?? "")
    }

    // MARK: - Actions

    private func openFileImport() {
        if appState.isEntitled(to: .documentImport) {
            showFileImporter = true
        } else {
            Task { await appState.present(.premiumPaywall) }
        }
    }

    private func runScan(_ work: @escaping @MainActor () async -> Void) {
        Task {
            await work()
            await appState.handleScanOutcome(scanViewModel, services: services)
        }
    }

    /// Multi-page documents can yield multiple events; present them together for review
    /// rather than opening only the first event and leaving the rest in the queue.
    private func runDocumentScan(at url: URL) {
        Task {
            _ = await scanViewModel.scanDocument(at: url, modelContext: modelContext)
            guard case .complete(let candidates) = scanViewModel.stage, candidates.count > 1 else {
                await appState.handleScanOutcome(scanViewModel, services: services)
                return
            }

            appState.rememberSourceImage(scanViewModel.currentProcessingImage, for: candidates)
            let events = candidates.map { candidate in
                BatchEventItem(
                    candidate: candidate,
                    screenshotID: UUID(),
                    screenshotLabel: "Imported document",
                    screenshotImage: scanViewModel.currentProcessingImage,
                    services: services
                )
            }
            await appState.presentBatchReview(BatchReviewSession(events: events))
        }
    }

    /// Single-photo pick keeps the classic full-review flow.
    private func runSinglePhotoScan(_ item: PhotosPickerItem) {
        runScan {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                scanViewModel.stage = .failed("That photo could not be loaded.")
                return
            }
            await scanViewModel.scanImageData(data, assetIdentifier: item.itemIdentifier ?? UUID().uuidString, modelContext: modelContext)
        }
    }

    /// A multi-item scan waiting on the free-allowance check.
    enum PendingBatch {
        case photos([PhotosPickerItem])
        case cameraPages([UIImage])

        var count: Int {
            switch self {
            case .photos(let items): return items.count
            case .cameraPages(let pages): return pages.count
            }
        }
    }

    private func handlePickedPhotos(_ items: [PhotosPickerItem]) {
        switch items.count {
        case 0: return
        case 1: runSinglePhotoScan(items[0])
        default: requestBatch(.photos(items))
        }
    }

    /// Runs the batch only if it fits the free allowance; otherwise asks the user to deselect,
    /// upgrade, or discard. Nothing is scanned or skipped silently.
    private func requestBatch(_ batch: PendingBatch) {
        let remaining = services.scanUsage.remainingFreeScans()
        let excess = PlanLimits.batchExcess(selecting: batch.count, snapshot: services.subscription.entitlementSnapshot, remaining: remaining)
        guard excess > 0 else {
            run(batch)
            return
        }
        pendingBatch = batch
        batchOverLimit = BatchOverLimit(selected: batch.count, remaining: remaining)
    }

    private func trimPendingBatch(to allowed: Int) {
        guard let pending = pendingBatch else { return }
        pendingBatch = nil
        switch pending {
        case .photos(let items):
            // Reopen the picker with the selection intact so the user chooses what to drop.
            isTrimmingPhotoSelection = true
            selectedPhotoItems = items
            showPhotoPicker = true
        case .cameraPages(let pages):
            run(.cameraPages(Array(pages.prefix(allowed))))
        }
    }

    /// Multi-item scan: every page or photo is scanned, then reviewed together.
    private func run(_ batch: PendingBatch) {
        let sources: [BatchScanSource]
        switch batch {
        case .photos(let items):
            sources = items.map { BatchScanSource.photoPicker($0) }
        case .cameraPages(let pages):
            sources = pages.enumerated().map { index, image in
                BatchScanSource.loaded(id: "camera-page-\(index + 1)-\(UUID().uuidString)", image: image)
            }
        }
        Task {
            await appState.startBatchScan(sources: sources, services: services, modelContext: modelContext)
        }
    }

    private func scanRecentScreenshots() {
        Task {
            guard await homeViewModel.ensurePhotoAccess() else {
                showPhotoAccessAlert = true
                return
            }
            homeViewModel.loadRecentScreenshots(limit: 30)
            Task { await appState.present(.recentScreenshots) }
        }
    }
}

private extension View {
    func cardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceContainer.opacity(0.75))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
    }
}

/// Stitch's `active:scale-[0.985]` press feedback for source cards.
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.title
            configuration.icon
        }
    }
}

/// The three glowing signature ribbons from the Stitch "Recent screenshots" hero card.
private struct SignatureRibbons: View {
    var body: some View {
        Canvas { context, size in
            let sx = size.width / 360, sy = size.height / 180
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let ribbons: [(Color, CGFloat, [CGPoint])] = [
                (.pdOrange, 2.5, [pt(-20, 160), pt(80, 120), pt(140, 30), pt(260, 50), pt(310, 58), pt(350, 20), pt(390, -10)]),
                (.pdTertiaryContainer, 1.75, [pt(0, 180), pt(110, 140), pt(170, 70), pt(280, 85), pt(330, 92), pt(360, 60), pt(400, 40)]),
                (.pdLavender, 1.5, [pt(30, 190), pt(130, 160), pt(200, 110), pt(310, 120), pt(350, 125), pt(380, 100), pt(410, 80)])
            ]
            for (color, width, p) in ribbons {
                var path = Path()
                path.move(to: p[0])
                path.addCurve(to: p[3], control1: p[1], control2: p[2])
                path.addCurve(to: p[6], control1: p[4], control2: p[5])
                var glow = context
                glow.addFilter(.shadow(color: color, radius: 5))
                glow.stroke(path, with: .color(color.opacity(0.7)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
