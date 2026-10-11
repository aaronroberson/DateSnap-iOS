import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers

enum HomeBrandCopy {
    static let captureHeading = "Capture Events"
    static let captureSubtitle = "Select a source and all the details will be Pencil'd in for you automatically once you confirm."
    static let photoLibraryPermissionMessage = "Pencil'd needs Photo Library access to find your recent screenshots. You can still pick individual photos without it."
    static let premiumFileImportAccessibilityHint = "Requires Pencil'd Premium"
    static let plusScreenshotExplanation = "Pencil'd Plus checks new screenshots on your device and highlights likely events. Nothing is saved until you review it."
    static let privacyHeading = "Private & On-Device Intelligence"
    static let privacyBody = "Your photos, screenshots, and documents never leave this device. Neural parsing happens locally in secure memory."
}

/// Capture home (Stitch "Source Chooser"): pick where the next event comes from.
/// Every source routes into the existing scan pipeline and review flow.
struct HomeEmptyStateView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Query private var scannedAssets: [ScannedAsset]
    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showPhotoAccessAlert: Bool = false

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
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    topBar
                    titleBlock
                    recentScreenshotsCard
                    photoLibraryCard
                    fileImportCard
                    createEventCard
                    sampleFlyerCard
                    privacyFooter
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.pdSurface.ignoresSafeArea())
            .overlay { ScanProgressOverlay(scan: scanViewModel) }
            .overlay { BatchScanProgressOverlay() }
            .animation(.easeInOut(duration: 0.2), value: scanViewModel.isProcessing)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItems, matching: .images, photoLibrary: .shared())
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                selectedPhotoItems = []
                if items.count == 1 {
                    runSinglePhotoScan(items[0])
                } else {
                    runBatchPhotoScan(items)
                }
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
                    runScan { await scanViewModel.scanDocument(at: url, modelContext: modelContext) }
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

    // MARK: - Header

    private var topBar: some View {
        HStack {
            Text("Capture")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.pdOnSurface)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = .settings }
            } label: {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.pdPrimary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.pdSurfaceContainer))
            }
            .accessibilityLabel("Profile and settings")
        }
        .padding(.top, 6)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTURE")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.pdPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.pdPrimary.opacity(0.12)))
            Text(HomeBrandCopy.captureHeading)
                .font(.system(size: 34, weight: .heavy))
                .foregroundStyle(LinearGradient.pdSignature)
            Text(HomeBrandCopy.captureSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(Color.pdOnSurfaceVariant)
        }
    }

    // MARK: - Source cards

    private var recentScreenshotsCard: some View {
        let autoDetect = appState.isEntitled(to: .automaticScreenshotDetection)
        return VStack(alignment: .leading, spacing: 14) {
            Button(action: scanRecentScreenshots) {
                HStack(alignment: .top, spacing: 14) {
                    sourceIcon("photo.on.rectangle.angled")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent screenshots")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.pdOnSurface)
                        Text("Auto-detect event flyers, ticket bookings, and tour announcements.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .disabled(scanViewModel.isProcessing)
            .accessibilityHint("Shows your recent screenshots to scan")

            if photosAuthorized && !newScreenshots.isEmpty {
                HStack(spacing: 8) {
                    ForEach(newScreenshots.prefix(3), id: \.localIdentifier) { asset in
                        Button {
                            runScan { await scanViewModel.scanAsset(asset, modelContext: modelContext) }
                        } label: {
                            AssetThumbnail(asset: asset, height: 72)
                                .frame(width: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(scanViewModel.isProcessing)
                        .accessibilityLabel("Scan screenshot from \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                    }
                    if newScreenshots.count > 3 {
                        Text("+\(newScreenshots.count - 3)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .frame(width: 52, height: 72)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.pdSurfaceContainerHigh))
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
                Text("Allow Photos access and Pencil\u{2019}d will surface new event screenshots here.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }

            HStack(spacing: 10) {
                if needingReviewCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { appState.selectedTab = .review }
                    } label: {
                        statusPill("\(needingReviewCount) Needing Review", icon: "checklist", tint: Color.pdCoral)
                    }
                }
                Spacer(minLength: 0)
                if autoDetect {
                    Label("Auto-scanned", systemImage: "bolt.badge.automatic.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.pdPrimary)
                } else {
                    Button {
                        appState.activeModal = .plusPaywall
                    } label: {
                        Label("Auto-detect with Plus", systemImage: "lock.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.pdPrimary)
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint(HomeBrandCopy.plusScreenshotExplanation)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color.pdSurfaceContainerHigh, Color.pdSurfaceContainer], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.pdPrimary.opacity(0.28), lineWidth: 1))
        )
    }

    private var photoLibraryCard: some View {
        sourceRow(
            icon: "photo.stack",
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
            icon: entitled ? "doc.text.viewfinder" : "lock.fill",
            title: "PDF or file import",
            detail: "Multi-page conference schedules, syllabi, flight itineraries & documents.",
            chips: entitled ? ["PDF", "Images", "iCloud Drive"] : ["PDF", "Images", "Premium"],
            hint: entitled ? "Scan a PDF or image from Files" : HomeBrandCopy.premiumFileImportAccessibilityHint
        ) {
            openFileImport()
        }
    }

    private var createEventCard: some View {
        Button {
            if let url = URL(string: "calshow://") { openURL(url) }
        } label: {
            HStack(spacing: 14) {
                sourceIcon("calendar.badge.plus")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Create an event")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pdOnSurface)
                    Text("Opens the Calendar app for manually creating events and notifications.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.pdPrimary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.pdPrimary.opacity(0.14)))
            }
            .padding(18)
            .cardBackground()
        }
        .accessibilityHint("Opens the Calendar app")
    }

    private var sampleFlyerCard: some View {
        Button {
            runScan { await scanViewModel.scanSampleFlyer(modelContext: modelContext) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    sourceIcon("wand.and.stars")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try sample flyer")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.pdOnSurface)
                        Text("See how Pencil'd automatically extracts complex dates, recurring slots, and reminders in real-time.")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.pdOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    statusPill("Interactive demo", icon: "play.circle.fill", tint: Color.pdLavender)
                    Spacer()
                    Text("No photo access needed")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.pdLavender.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.pdLavender.opacity(0.28), lineWidth: 1))
            )
        }
        .disabled(scanViewModel.isProcessing)
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18))
                .foregroundStyle(Color.pdPrimary)
            VStack(alignment: .leading, spacing: 4) {
                Text(HomeBrandCopy.privacyHeading)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.pdOnSurface)
                Text(HomeBrandCopy.privacyBody)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.pdSurfaceLowest))
        .padding(.top, 4)
    }

    // MARK: - Card building blocks

    private func sourceIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.pdPrimary)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.pdPrimary.opacity(0.14)))
    }

    private func statusPill(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private func sourceRow(
        icon: String,
        title: String,
        detail: String,
        chips: [String],
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    sourceIcon(icon)
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.pdOnSurface)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                }
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.pdOnSurfaceVariant)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        Text(chip)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.pdOnSurface.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.pdSurfaceContainerHigh))
                    }
                }
            }
            .padding(18)
            .cardBackground()
        }
        .disabled(scanViewModel.isProcessing)
        .accessibilityHint(hint ?? "")
    }

    // MARK: - Actions

    private func openFileImport() {
        if appState.isEntitled(to: .documentImport) {
            showFileImporter = true
        } else {
            appState.activeModal = .premiumPaywall
        }
    }

    private func runScan(_ work: @escaping @MainActor () async -> Void) {
        Task {
            await work()
            await appState.handleScanOutcome(scanViewModel)
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

    /// Multi-photo pick: scan every selected screenshot, then review all together.
    private func runBatchPhotoScan(_ items: [PhotosPickerItem]) {
        Task {
            await appState.startBatchScan(
                sources: items.map { BatchScanSource.photoPicker($0) },
                services: services,
                modelContext: modelContext
            )
        }
    }

    private func scanRecentScreenshots() {
        Task {
            guard await homeViewModel.ensurePhotoAccess() else {
                showPhotoAccessAlert = true
                return
            }
            homeViewModel.loadRecentScreenshots(limit: 30)
            appState.activeModal = .recentScreenshots
        }
    }
}

private extension View {
    func cardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.pdSurfaceContainer)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.pdOutlineVariant.opacity(0.4), lineWidth: 1))
        )
    }
}

// MARK: - Custom Corner Bracket Shape
enum CornerBracketPosition {
    case topLeft, topRight, bottomLeft, bottomRight
}

struct RoundedCornerBracket: Shape {
    var corner: CornerBracketPosition
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius: CGFloat = 8
        
        switch corner {
        case .topLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .topRight:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomLeft:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottomRight:
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - radius), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        
        return path
    }
}
