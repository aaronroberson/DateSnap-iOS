import SwiftUI
import SwiftData
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct HomeEmptyStateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var scanViewModel: ScanViewModel
    @EnvironmentObject private var homeViewModel: HomeViewModel
    @Query private var scannedAssets: [ScannedAsset]

    @State private var scanLaserDown: Bool = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showPhotoAccessAlert: Bool = false

    /// Screenshots the library observer has seen that DateSnap has not scanned yet (Plus auto-detection).
    private var newScreenshots: [PHAsset] {
        let scanned = Set(scannedAssets.map(\.assetIdentifier))
        let unscanned = homeViewModel.recentScreenshots.filter { !scanned.contains($0.localIdentifier) }
        guard appState.isEntitled(to: .likelyEventTriage) else { return unscanned }
        return PhotoCandidateRanker.rank(unscanned, scannedIDs: scanned, likelyEventIDs: homeViewModel.likelyEventIDs)
    }
    
    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Header Bar with Membership Badge
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                Text("AI TEMPORAL SYNC")
                                    .font(DSTypography.overlineConfidence())
                            }
                            .foregroundStyle(Color.dsPrimary)
                            
                            Text("Welcome to DateSnap")
                                .font(DSTypography.displayTitle())
                                .foregroundStyle(Color.dsForeground)
                            
                            Text("Your camera roll's calendar autopilot.")
                                .font(DSTypography.bodyCompact())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        
                        Spacer()
                        
                        // Paywall / Tier Pill
                        Button {
                            if appState.isPremiumMember {
                                appState.showToast("DateSnap Premium Active")
                            } else if appState.isPlusMember {
                                appState.activeModal = .premiumPaywall
                            } else {
                                appState.activeModal = .plusPaywall
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: appState.isPremiumMember ? "crown.fill" : (appState.isPlusMember ? "bolt.fill" : "sparkle"))
                                    .font(.system(size: 11))
                                Text(appState.isPremiumMember ? "PREMIUM" : (appState.isPlusMember ? "PLUS" : "FREE"))
                                    .font(DSTypography.overlineConfidence())
                            }
                            .foregroundStyle(appState.isPremiumMember ? Color.dsWarning : Color.dsPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(appState.isPremiumMember ? Color.dsWarning.opacity(0.16) : Color.dsPrimary.opacity(0.12))
                                    .overlay(
                                        Capsule()
                                            .stroke(appState.isPremiumMember ? Color.dsWarning.opacity(0.4) : Color.dsPrimary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    // Main Hero Container with Ambient Glows & 4-Corner Multi-Color Laser Brackets
                    VStack(spacing: 16) {
                        // Ticket Showcase Card with 4-Corner Neon Brackets & Scanning Laser
                        ZStack {
                            // Ambient Radial Glows behind flyer
                            Circle()
                                .fill(Color.dsSecondary.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .blur(radius: 30)
                                .offset(x: 40, y: -30)
                            Circle()
                                .fill(Color.dsPrimary.opacity(0.2))
                                .frame(width: 140, height: 140)
                                .blur(radius: 30)
                                .offset(x: -40, y: 30)
                            
                            // Mock Ticket Outer Wrapper (with corner brackets)
                            ZStack {
                                // Corner 1: Top-Left (Cyan)
                                VStack {
                                    HStack {
                                        RoundedCornerBracket(corner: .topLeft)
                                            .stroke(Color.dsPrimary, lineWidth: 2.5)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Color.dsPrimary.opacity(0.8), radius: 6)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                
                                // Corner 2: Top-Right (Purple)
                                VStack {
                                    HStack {
                                        Spacer()
                                        RoundedCornerBracket(corner: .topRight)
                                            .stroke(Color(red: 123/255, green: 97/255, blue: 255/255), lineWidth: 2.5)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Color(red: 123/255, green: 97/255, blue: 255/255).opacity(0.8), radius: 6)
                                    }
                                    Spacer()
                                }
                                
                                // Corner 3: Bottom-Left (Orange)
                                VStack {
                                    Spacer()
                                    HStack {
                                        RoundedCornerBracket(corner: .bottomLeft)
                                            .stroke(Color(red: 255/255, green: 138/255, blue: 61/255), lineWidth: 2.5)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Color(red: 255/255, green: 138/255, blue: 61/255).opacity(0.8), radius: 6)
                                        Spacer()
                                    }
                                }
                                
                                // Corner 4: Bottom-Right (Cyan)
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        RoundedCornerBracket(corner: .bottomRight)
                                            .stroke(Color.dsPrimary, lineWidth: 2.5)
                                            .frame(width: 22, height: 22)
                                            .shadow(color: Color.dsPrimary.opacity(0.8), radius: 6)
                                    }
                                }
                                
                                // Inner Ticket Card
                                VStack(spacing: 8) {
                                    // Window control traffic dots + crop icon
                                    HStack {
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.dsError.opacity(0.8)).frame(width: 6, height: 6)
                                            Circle().fill(Color.dsWarning.opacity(0.8)).frame(width: 6, height: 6)
                                            Circle().fill(Color.dsSuccess.opacity(0.8)).frame(width: 6, height: 6)
                                        }
                                        Spacer()
                                        Image(systemName: "viewfinder")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                    
                                    // Flyer Image Area with Animated Scanning Laser
                                    ZStack(alignment: .top) {
                                        // Poster Visual
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 79/255, blue: 179/255).opacity(0.6),
                                                Color(red: 91/255, green: 124/255, blue: 255/255).opacity(0.5),
                                                Color.dsBackground
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .frame(height: 76)
                                        .cornerRadius(8)
                                        .overlay(
                                            VStack(spacing: 2) {
                                                Image(systemName: "music.mic")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Color.white.opacity(0.9))
                                                Text("NEON MIRAGE")
                                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                                    .foregroundStyle(Color.white)
                                            }
                                        )
                                        
                                        // Scanning Laser Beam
                                        Rectangle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        Color(red: 255/255, green: 138/255, blue: 61/255),
                                                        Color.dsPrimary,
                                                        Color(red: 123/255, green: 97/255, blue: 255/255)
                                                    ],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(height: 2)
                                            .shadow(color: Color.dsPrimary, radius: 4, y: 0)
                                            .offset(y: scanLaserDown ? 70 : 4)
                                            .animation(Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: scanLaserDown)
                                    }
                                    
                                    // Event Meta
                                    HStack {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("Neon Mirage Tour")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(Color.dsForeground)
                                            Text("Oct 24 • 8:00 PM")
                                                .font(.system(size: 9))
                                                .foregroundStyle(Color.dsMutedForeground)
                                        }
                                        Spacer()
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.dsPrimary)
                                    }
                                    
                                    // Bottom Sync Speed Strip
                                    HStack {
                                        Text("Ready to sync")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(Color.dsPrimary)
                                        Spacer()
                                        Text("0.4s")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Color.dsMutedForeground)
                                    }
                                }
                                .padding(10)
                                .frame(width: 170, height: 190)
                                .background(Color.dsCardElevated.opacity(0.95))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }
                            .frame(width: 186, height: 206)
                        }
                        .padding(.top, 8)
                        
                        // Empty State Main Pitch
                        VStack(spacing: 6) {
                            Text(scannedAssets.isEmpty ? "No screenshots scanned yet" : "Ready for your next flyer")
                                .font(DSTypography.headlineSection())
                                .foregroundStyle(Color.dsForeground)
                                .multilineTextAlignment(.center)
                            
                            Text("Take a screenshot of a flyer, text invite, or ticket, and DateSnap will instantly turn it into a calendar event with custom reminders.")
                                .font(DSTypography.bodyCompact())
                                .foregroundStyle(Color.dsMutedForeground)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button {
                                scanRecentScreenshots()
                            } label: {
                                HStack(spacing: 8) {
                                    if scanViewModel.isProcessing {
                                        ProgressView().tint(Color.dsPrimaryForeground)
                                        Text("Analyzing Screenshot...")
                                    } else {
                                        Image(systemName: "camera.viewfinder")
                                        Text("Scan Recent Screenshots")
                                        Image(systemName: "arrow.right")
                                    }
                                }
                            }
                            .buttonStyle(DSPrimaryButtonStyle())
                            .disabled(scanViewModel.isProcessing)
                            
                            Button {
                                showPhotoPicker = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Choose from Photo Library")
                                }
                            }
                            .buttonStyle(DSSecondaryButtonStyle())
                            .disabled(scanViewModel.isProcessing)

                            Button {
                                if appState.isEntitled(to: .documentImport) {
                                    showFileImporter = true
                                } else {
                                    appState.activeModal = .premiumPaywall
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: appState.isPremiumMember ? "doc.text.viewfinder" : "lock.fill")
                                    Text("Import PDF or File")
                                    if !appState.isPremiumMember {
                                        Text("PREMIUM")
                                            .font(DSTypography.overlineConfidence())
                                            .foregroundStyle(Color.dsWarning)
                                    }
                                }
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsForeground)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .disabled(scanViewModel.isProcessing)
                            .accessibilityHint(appState.isPremiumMember ? "Scan a PDF or image from Files" : "Requires DateSnap Premium")
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .dsGlassCard(cornerRadius: 28, elevated: true, borderColor: Color.dsPrimary.opacity(0.2))
                    .padding(.horizontal)

                    autoDetectedScreenshotsCard
                    
                    // "How DateSnap Works" 3 Effortless Steps
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("How DateSnap Works")
                                .font(DSTypography.headlineCard())
                                .foregroundStyle(Color.dsForeground)
                            Spacer()
                            Text("3 effortless steps")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsPrimary)
                        }
                        
                        stepCard(
                            icon: "camera.viewfinder",
                            iconColor: Color(red: 255/255, green: 138/255, blue: 61/255),
                            title: "1. Snap or Screenshot",
                            description: "Capture Instagram stories, WhatsApp messages, concert posters, or emailed invitations."
                        )
                        
                        stepCard(
                            icon: "bolt.fill",
                            iconColor: Color.dsPrimary,
                            title: "2. Open DateSnap",
                            description: "On-device neural vision parses dates, venue locations, and start/end times in 0.4 seconds."
                        )
                        
                        stepCard(
                            icon: "calendar.badge.checkmark",
                            iconColor: Color(red: 123/255, green: 97/255, blue: 255/255),
                            title: "3. One-Tap Save",
                            description: "Inspect details, tap sync, and push directly to Apple Calendar, Google Calendar, or Reminders."
                        )
                    }
                    .padding(18)
                    .dsGlassCard(cornerRadius: 22)
                    .padding(.horizontal)
                    
                    // "Curious how it works? Try Sample Flyer" — runs the real OCR + inference pipeline
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 255/255, green: 138/255, blue: 61/255), Color(red: 123/255, green: 97/255, blue: 255/255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 56)
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Curious how it works?")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                            Text("Scan a sample concert flyer — no photo access needed.")
                                .font(DSTypography.caption())
                                .foregroundStyle(Color.dsMutedForeground)
                        }
                        
                        Spacer()
                        
                        Button {
                            runScan { await scanViewModel.scanSampleFlyer(modelContext: modelContext) }
                        } label: {
                            Text("Try Sample Flyer")
                                .font(DSTypography.labelChip())
                                .foregroundStyle(Color.dsPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .background(Capsule().fill(Color.dsSecondary.opacity(0.18)))
                        }
                        .disabled(scanViewModel.isProcessing)
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 20, elevated: true, borderColor: Color.dsSecondary.opacity(0.25))
                    .padding(.horizontal)
                    
                    // On-Device Privacy Badge
                    HStack(spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dsMutedForeground)
                        Text("All processing runs private and on-device. Zero cloud storage.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                    }
                    .padding(.horizontal)
                    
                    #if DEBUG
                    // Simulation & Quick Access Center
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "slider.horizontal.2.square")
                                .foregroundStyle(Color.dsInfo)
                            Text("Screen State & Simulation Hub")
                                .font(DSTypography.bodyStrong())
                                .foregroundStyle(Color.dsForeground)
                        }
                        
                        Text("Quick access to test all 10 project screens and permission flows:")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            simButton(title: "No Dates Found", icon: "magnifyingglass.circle") {
                                appState.activeModal = .noDatesFound
                            }
                            
                            simButton(title: "Calendar Denied", icon: "calendar.badge.exclamationmark") {
                                appState.activeModal = .calendarPermissionDenied
                            }
                            
                            simButton(title: "Notify Denied", icon: "bell.slash") {
                                appState.activeModal = .notificationPermissionDenied
                            }
                            
                            simButton(title: "Plus Paywall", icon: "bolt.fill") {
                                appState.activeModal = .plusPaywall
                            }
                            
                            simButton(title: "Premium Paywall", icon: "crown.fill") {
                                appState.activeModal = .premiumPaywall
                            }
                        }
                    }
                    .padding(16)
                    .dsGlassCard(cornerRadius: 20, elevated: true, borderColor: Color.dsInfo.opacity(0.25))
                    .padding(.horizontal)
                    #endif

                    Color.clear.frame(height: 90)
                }
            }
            .dsScreenBackground()
            .overlay { ScanProgressOverlay(scan: scanViewModel) }
            .overlay { BatchScanProgressOverlay() }
            .animation(.easeInOut(duration: 0.2), value: scanViewModel.isProcessing)
            .onAppear {
                scanLaserDown = true
            }
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
                Text("DateSnap needs Photo Library access to find your recent screenshots. You can still pick individual photos without it.")
            }
        }
    }

    // MARK: - Scan Actions
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

    // MARK: - Plus: Automatic Screenshot Detection
    @ViewBuilder
    private var autoDetectedScreenshotsCard: some View {
        let photosAuthorized = homeViewModel.photoAuthorizationStatus == .authorized || homeViewModel.photoAuthorizationStatus == .limited
        if appState.isEntitled(to: .automaticScreenshotDetection) && photosAuthorized && !newScreenshots.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("New screenshots detected", systemImage: "bolt.badge.automatic.fill")
                        .font(DSTypography.bodyStrong())
                        .foregroundStyle(Color.dsForeground)
                    Spacer()
                    Text("\(newScreenshots.count) new")
                        .font(DSTypography.caption())
                        .foregroundStyle(Color.dsPrimary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(newScreenshots.prefix(8), id: \.localIdentifier) { asset in
                            Button {
                                runScan { await scanViewModel.scanAsset(asset, modelContext: modelContext) }
                            } label: {
                                AssetThumbnail(asset: asset, height: 120)
                                    .frame(width: 80)
                                    .overlay(alignment: .bottom) {
                                        if homeViewModel.likelyEventIDs.contains(asset.localIdentifier) {
                                            Label("Event", systemImage: "calendar.badge.checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(Color.dsBackground)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Capsule().fill(Color.dsPrimary))
                                                .padding(.bottom, 6)
                                        }
                                    }
                            }
                            .accessibilityLabel("Scan screenshot from \(asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "unknown date")")
                        }
                    }
                }
                Text("DateSnap Plus watches your Screenshots album, checks new ones on device, and shows likely events first. Nothing is saved until you review it.")
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
            .padding(16)
            .dsGlassCard(cornerRadius: 20, elevated: true, borderColor: Color.dsPrimary.opacity(0.3))
            .padding(.horizontal)
            .task(id: homeViewModel.recentScreenshots.map(\.localIdentifier)) {
                if appState.isEntitled(to: .likelyEventTriage) {
                    homeViewModel.triageLikelyEvents(scannedIDs: Set(scannedAssets.map(\.assetIdentifier)))
                }
            }
        } else if !appState.isEntitled(to: .automaticScreenshotDetection) {
            Button {
                appState.activeModal = .plusPaywall
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.badge.automatic.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.dsPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatic screenshot detection")
                            .font(DSTypography.bodyStrong())
                            .foregroundStyle(Color.dsForeground)
                        Text("New event screenshots appear here automatically with Plus.")
                            .font(DSTypography.caption())
                            .foregroundStyle(Color.dsMutedForeground)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.dsMutedForeground)
                }
                .padding(16)
                .dsGlassCard(cornerRadius: 20)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func stepCard(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DSTypography.bodyStrong())
                    .foregroundStyle(Color.dsForeground)
                Text(description)
                    .font(DSTypography.caption())
                    .foregroundStyle(Color.dsMutedForeground)
            }
        }
    }
    
    @ViewBuilder
    private func simButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(DSTypography.caption())
                    .lineLimit(1)
            }
            .foregroundStyle(Color.dsForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dsCardElevated)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dsBorder, lineWidth: 1))
            )
        }
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
