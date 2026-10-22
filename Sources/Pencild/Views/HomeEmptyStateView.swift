import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers
import VisionKit

enum HomeBrandCopy {
    static let captureHeading = "Turn Schedules Into Events"
    static let captureSubtitle = "Scan flyers, import syllabi, or let Pencil’d Plus spot events in your new screenshots."
    static let photoLibraryPermissionMessage = "Pencil’d needs Photo Library access to find your recent screenshots. You can still pick individual photos without it."
    static let premiumFileImportAccessibilityHint = "Requires Pencil’d Premium"
    static let plusScreenshotExplanation = "Pencil’d Plus checks new screenshots on your device and highlights likely events. Nothing is saved until you review it."
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
    /// Keeps a file-import request alive while the Premium paywall is open.
    @State private var pendingFileImportAfterPurchase = false
    @State private var showPhotoPicker: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showPhotoAccessAlert: Bool = false
    @State private var showDocumentCamera: Bool = false
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                captureContent
            }
            .background(Color.pdSurface.ignoresSafeArea())
            .animation(.easeInOut(duration: 0.2), value: scanViewModel.isProcessing)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItems, matching: .images)
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
                onUpgrade: { Task { await appState.present(.paywall(opening: .plus)) } },
                onDiscard: { pendingBatch = nil }
            )
            .onChange(of: appState.subscriptionTier) { _, tier in
                // Upgraded from the prompt: run the batch the user had chosen.
                if tier != .starter, let pending = pendingBatch {
                    pendingBatch = nil
                    run(pending)
                }
                if tier == .premium, pendingFileImportAfterPurchase {
                    pendingFileImportAfterPurchase = false
                    showFileImporter = true
                }
            }
            .onChange(of: appState.requestPhotoPicker) { _, requested in
                if requested {
                    appState.requestPhotoPicker = false
                    showPhotoPicker = true
                }
            }
            .onChange(of: appState.requestDocumentScanner) { _, requested in
                if requested {
                    appState.requestDocumentScanner = false
                    openDocumentScanner()
                }
            }
            .onChange(of: appState.requestScreenshotPicker) { _, requested in
                if requested {
                    appState.requestScreenshotPicker = false
                    scanRecentScreenshots()
                }
            }
            .onChange(of: appState.requestFileImporter) { _, requested in
                if requested {
                    appState.requestFileImporter = false
                    openFileImport()
                }
            }
            .onAppear {
                consumePendingCaptureRequest()
            }
            .onChange(of: appState.activeModal?.id) { _, newID in
                // A successful purchase can dismiss the paywall before the entitlement publisher
                // delivers its tier change. Keep the intent through that handoff, but discard it
                // when the user simply closes the paywall without gaining access.
                if newID == nil, !appState.isEntitled(to: .documentImport) {
                    pendingFileImportAfterPurchase = false
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
                SubscriptionStatusBanner()
                scanAllowanceBanner
                recentScreenshotsCard
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 16) {
                    sourceCards
                    sampleFlyerCard
                    deconflictionDemosCard
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
                SubscriptionStatusBanner()
                scanAllowanceBanner
                recentScreenshotsCard
                sourceCards
                sampleFlyerCard
                deconflictionDemosCard
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
            Image("PencildTurnSchedulesShiny")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 160)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                .accessibilityLabel("Pencil’d — \(HomeBrandCopy.captureHeading)")
                .accessibilityAddTraits(.isHeader)
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
        CaptureScreenshotsCard(isDisabled: scanViewModel.isProcessing, action: scanRecentScreenshots) {
            CaptureScreenshotsFooter(
                onScanAsset: { asset in
                    runScan { await scanViewModel.scanAsset(asset, modelContext: modelContext) }
                },
                onReview: {
                    withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = .review }
                }
            )
        }
    }

    /// Free plan only: how many of this month's scans remain, with a path to Plus.
    @ViewBuilder
    private var scanAllowanceBanner: some View {
        if PlanLimits.limitsScans(appState.entitlementSnapshot) {
            let remaining = services.scanUsage.remainingFreeScans()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: PDSpacing.sm) {
                    Image(systemName: remaining == 0 ? "exclamationmark.circle.fill" : "sparkle")
                        .foregroundStyle(remaining == 0 ? Color.pdWarning : Color.pdPrimary)
                        .accessibilityHidden(true)
                    Text(remaining == 0
                         ? "No free scans left this month"
                         : remaining == 1
                            ? "1 free scan left this month"
                            : "\(remaining) of \(PlanLimits.freeScansPerMonth) free scans left this month")
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdOnSurface)
                    Spacer(minLength: PDSpacing.sm)
                    Button("Upgrade") { Task { await appState.present(.paywall(opening: .plus)) } }
                        .font(PDFont.labelLG)
                        .foregroundStyle(Color.pdPrimary)
                        .frame(minHeight: 44)
                }
                if remaining == 1 {
                    Text("Only scans that find a new event count. Upgrade for unlimited scanning.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .padding(.leading, 28)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, PDSpacing.md)
            .padding(.vertical, PDSpacing.xs)
            .background(
                (remaining == 1 ? Color.pdWarning.opacity(0.14) : Color.pdSurfaceContainer.opacity(0.85)),
                in: RoundedRectangle(cornerRadius: PDRadius.card)
            )
            .accessibilityElement(children: .combine)
        }
    }

    /// Every capture source after Screenshots (which has its own richer card above), in the shared
    /// `CaptureSource` order and labels used by the Add events sheet and the welcome screen.
    @ViewBuilder
    private var sourceCards: some View {
        ForEach(CaptureSource.allCases.filter { $0 != .screenshots }) { source in
            CaptureSourceRow(source: source) { start(source) }
                .disabled(scanViewModel.isProcessing && source != .manual)
        }
    }

    private func start(_ source: CaptureSource) {
        switch source {
        case .screenshots: scanRecentScreenshots()
        case .photoLibrary: showPhotoPicker = true
        case .fileImport: openFileImport()
        case .documentScanner: openDocumentScanner()
        case .manual:
            Task { await appState.startManualEntry(in: modelContext) }
        }
    }

    private func openDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            appState.showToast("Document scanning needs a device with a camera.")
            return
        }
        showDocumentCamera = true
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

    private var deconflictionDemosCard: some View {
        VStack(alignment: .leading, spacing: PDSpacing.sm) {
            HStack(alignment: .top, spacing: PDSpacing.md) {
                sourceIcon("sparkles.rectangle.stack", tint: .pdSecondary, fill: .pdSurfaceContainer)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Deconfliction Intelligence")
                        .font(PDFont.headlineSM)
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Preview how Pencil’d resolves time zone shears, cascading syllabus shifts, ambiguous audio notes, and weather delays.")
                        .font(PDFont.bodyMD)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: 8) {
                deconflictionPill(
                    icon: "airplane.departure",
                    title: "Transmeridian Flight & Timezone Shear",
                    subtitle: "SFO → HND date line crossover & dead-zone review clash",
                    tone: .pdPrimary
                ) {
                    Task { await appState.present(.transmeridianConflict) }
                }

                deconflictionPill(
                    icon: "doc.text.fill",
                    title: "Syllabus Addendum: Cascade Collisions",
                    subtitle: "+4 days exam push with 6-milestone domino chain",
                    tone: .pdSecondary
                ) {
                    Task { await appState.present(.syllabusCascadeConflict) }
                }

                deconflictionPill(
                    icon: "waveform",
                    title: "Ambient Audio Stream Deconfliction",
                    subtitle: "Conversational self-correction & radar slot comparison",
                    tone: .pdTertiary
                ) {
                    Task { await appState.present(.ambientAudioConflict) }
                }

                deconflictionPill(
                    icon: "cloud.bolt.rain.fill",
                    title: "Festival & Weather Contingency Radar",
                    subtitle: "Midnight headline delay collides with return Amtrak transit",
                    tone: .pdPrimaryContainer
                ) {
                    Task { await appState.present(.festivalWeatherConflict) }
                }
            }
        }
        .padding(PDSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PDRadius.card)
                .fill(Color.pdSurfaceLow)
        )
    }

    private func deconflictionPill(
        icon: String,
        title: String,
        subtitle: String,
        tone: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tone)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.pdSurfaceContainerHigh))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(PDFont.labelMD)
                        .bold()
                        .foregroundStyle(Color.pdOnSurface)
                    Text(subtitle)
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.pdPrimary)
            }
            .padding(PDSpacing.sm)
            .background(RoundedRectangle(cornerRadius: PDRadius.tile).fill(Color.pdSurfaceLowest.opacity(0.8)))
        }
        .buttonStyle(.plain)
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

    // MARK: - Actions

    /// Picker requests can be raised while the capture sheet is dismissing and Home is being
    /// mounted. Reconcile the request flags on appearance so that transition cannot lose a tap.
    private func consumePendingCaptureRequest() {
        if appState.requestPhotoPicker {
            appState.requestPhotoPicker = false
            showPhotoPicker = true
        } else if appState.requestDocumentScanner {
            appState.requestDocumentScanner = false
            openDocumentScanner()
        } else if appState.requestScreenshotPicker {
            appState.requestScreenshotPicker = false
            scanRecentScreenshots()
        } else if appState.requestFileImporter {
            appState.requestFileImporter = false
            openFileImport()
        }
    }

    private func openFileImport() {
        Task {
            switch await appState.authorize(.documentImport) {
            case .allowed:
                showFileImporter = true
            case .denied(.requiresTier):
                pendingFileImportAfterPurchase = true
                await appState.present(.paywall(for: .documentImport))
            case .denied(let reason):
                // StoreKit couldn't confirm the plan even after retrying: say so, don't sell.
                appState.showToast(FeatureAccessDecision.denied(reason).documentImportMessage)
            }
        }
    }

    private func runScan(_ work: @escaping @MainActor () async -> Void) {
        Task {
            await work()
            await appState.handleScanOutcome(scanViewModel, services: services)
        }
    }

    /// Multi-page documents can yield multiple events; present them together for review
    /// rather than opening only the first event and leaving the rest in the queue. iCloud Drive
    /// files that aren't downloaded locally are gated by the user's `ICloudDownloadPreference`.
    private func runDocumentScan(at url: URL) {
        let remote = RemoteAssetGate.isFileDownloadedLocally(url) == false
        guard remote else {
            runDocumentScanNow(at: url, allowICloudDownload: false)
            return
        }

        switch RemoteAssetGate.decide(remoteCount: 1, preference: ICloudDownloadPreference.standard) {
        case .proceed(let allow):
            runDocumentScanNow(at: url, allowICloudDownload: allow)
        case .skipRemotes:
            appState.showToast("Skipped iCloud-only file. Allow iCloud downloads in Settings to scan it.")
        case .ask:
            appState.pendingICloudSingle = ICloudSingleConfirmation(itemLabel: "file") { downloadAllowed in
                self.runDocumentScanNow(at: url, allowICloudDownload: downloadAllowed)
            }
        }
    }

    /// Runs the document scan with the resolved iCloud-download decision and routes the outcome.
    private func runDocumentScanNow(at url: URL, allowICloudDownload: Bool) {
        runScan {
            _ = await scanViewModel.scanDocument(at: url, modelContext: modelContext, allowICloudDownload: allowICloudDownload)
        }
    }

    /// Single-photo pick keeps the classic full-review flow.
    private func runSinglePhotoScan(_ item: PhotosPickerItem) {
        runScan {
            do {
                let data = try await item.loadTransferable(type: Data.self)
                guard let data, !data.isEmpty else {
                    scanViewModel.stage = .failed("This photo isn't downloaded to your device. If it's stored in iCloud, open it in Photos first, or allow iCloud downloads in Settings › Scanning Options.")
                    return
                }
                await scanViewModel.scanImageData(data, assetIdentifier: item.itemIdentifier ?? UUID().uuidString, modelContext: modelContext)
            } catch {
                scanViewModel.stage = .failed("This photo isn't downloaded to your device. If it's stored in iCloud, open it in Photos first, or allow iCloud downloads in Settings › Scanning Options.")
            }
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
    /// Routed through `AppState.requestBatchScan` so the iCloud/remote-asset gate can ask before
    /// any iCloud download happens.
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
            await appState.requestBatchScan(sources: sources, services: services, modelContext: modelContext)
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

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.title
            configuration.icon
        }
    }
}
