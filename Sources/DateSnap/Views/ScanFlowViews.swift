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
            await present(.eventReviewEdit(first.toDateSnapEvent()))
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
            selectedTab = .history
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

    private var stageText: String {
        switch scan.stage {
        case .fetchingImage: return "Loading image…"
        case .processingOCR: return "Checking text on-device…"
        case .extractingEvents: return "Finding dates & places…"
        case .interpreting: return "Interpreting event details on device…"
        default: return "Analyzing…"
        }
    }

    var body: some View {
        if scan.isProcessing {
            ZStack {
                Color.dsBackground.opacity(0.72).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.dsPrimary)
                    Text(stageText)
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    if let detail = scan.progressDetail {
                        Text(detail)
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    Label("Private, on-device processing", systemImage: "lock.shield.fill")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .padding(28)
                .dsGlassCard(cornerRadius: 24, elevated: true, borderColor: Color.dsPrimary.opacity(0.3))
            }
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - Recent Screenshots Gallery
struct RecentScreenshotsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @Query private var scannedAssets: [ScannedAsset]

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var scannedIds: Set<String> { Set(scannedAssets.map(\.assetIdentifier)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick a screenshot of a flyer, invite, or ticket. Text is read on this iPhone only.")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsMutedForeground)

                    if homeViewModel.isRefreshing && homeViewModel.recentScreenshots.isEmpty {
                        ProgressView().tint(Color.dsPrimary).frame(maxWidth: .infinity).padding(.top, 40)
                    } else if homeViewModel.recentScreenshots.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.dsMutedForeground)
                            Text("No screenshots found")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Text(homeViewModel.photoAuthorizationStatus == .limited
                                 ? "DateSnap can only see the photos you shared. Choose more in iOS Settings, or use Choose from Photo Library."
                                 : "Take a screenshot of an event, then come back.")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(homeViewModel.recentScreenshots, id: \.localIdentifier) { asset in
                                Button {
                                    scan(asset)
                                } label: {
                                    AssetThumbnail(asset: asset)
                                        .overlay(alignment: .topTrailing) {
                                            if scannedIds.contains(asset.localIdentifier) {
                                                Label("Scanned", systemImage: "checkmark.circle.fill")
                                                    .labelStyle(.iconOnly)
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Color.dsSuccess)
                                                    .padding(6)
                                                    .accessibilityLabel("Already scanned")
                                            }
                                        }
                                }
                                .accessibilityLabel("Screenshot from \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                            }
                        }
                    }
                }
                .padding()
            }
            .dsScreenBackground()
            .navigationTitle("Recent Screenshots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { homeViewModel.loadRecentScreenshots(limit: 30) }
        }
    }

    private func scan(_ asset: PHAsset) {
        dismiss()
        Task {
            await scanViewModel.scanAsset(asset, modelContext: modelContext)
            await appState.handleScanOutcome(scanViewModel)
        }
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
/// Scanned events that have not been saved yet, plus drafts. Replaces the prototype's single mock review screen.
struct ReviewQueueView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \EventCandidate.createdAt, order: .reverse) private var candidates: [EventCandidate]

    private var pending: [EventCandidate] {
        candidates.filter { $0.savedEvent == nil || $0.savedEvent?.status == .draft }
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REVIEW QUEUE")
                            .font(DSTypography.overlineConfidence())
                            .foregroundStyle(Color.dsPrimary)
                        Text("Needs Review")
                            .font(DSTypography.displayTitle())
                            .foregroundStyle(Color.dsForeground)
                        Text("Nothing is added to your calendar until you confirm it.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    .padding(.top, 10)

                    if pending.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 38))
                                .foregroundStyle(Color.dsSuccess)
                            Text("All caught up")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Text("Scan a screenshot or flyer from Home and detected events will wait here for your review.")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                                .multilineTextAlignment(.center)
                            Button {
                                appState.selectedTab = .home
                            } label: {
                                Label("Go to Scanner", systemImage: "camera.viewfinder")
                            }
                            .buttonStyle(DSSecondaryButtonStyle())
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(pending) { candidate in
                            Button {
                                appState.review(candidate)
                            } label: {
                                ReviewQueueRow(candidate: candidate)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .dsScreenBackground()
        }
    }
}

private struct ReviewQueueRow: View {
    let candidate: EventCandidate

    var body: some View {
        let event = candidate.toDateSnapEvent()
        let tier = candidate.confidenceTier
        HStack(spacing: 14) {
            DSDateBadge(month: event.month, day: event.day, isSelected: false)
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                    .lineLimit(1)
                Text("\(event.dayOfWeek) • \(event.timeWindow)")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: tier.iconName)
                    Text(candidate.savedEvent?.status == .draft ? "Draft · \(tier.label)" : tier.label)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(hex: tier.hexColor))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.dsMutedForeground)
        }
        .padding(14)
        .dsGlassCard(cornerRadius: 18)
    }
}
