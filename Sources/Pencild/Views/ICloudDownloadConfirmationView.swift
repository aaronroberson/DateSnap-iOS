import SwiftUI
import Photos

// MARK: - iCloud Batch Confirmation Sheet
/// Presented from `ContentView` when `AppState.pendingICloudBatch` is set. The user chooses to
/// download all iCloud-only sources, skip them, or open the per-photo chooser (which lets them
/// select which iCloud items to download, discarding the deselected ones).
struct ICloudBatchConfirmationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let confirmation: ICloudBatchConfirmation
    @State private var showPerPhoto = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PDSpacing.lg) {
                    PDScreenIntro(
                        eyebrow: "iCloud Ingestion",
                        title: "Some sources are in iCloud",
                        subtitle: "\(confirmation.remoteCount) of \(confirmation.totalCount) item\(confirmation.totalCount == 1 ? "" : "s") are stored in iCloud and aren't on this device yet. Pencil’d only scans on-device photos, PDFs, and files unless you allow it."
                    )
                    PDCard(highlighted: true) {
                        VStack(alignment: .leading, spacing: PDSpacing.sm) {
                            HStack(spacing: 10) {
                                PDIconTile(systemName: "icloud.fill", tint: .pdPrimary, size: .large)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(confirmation.remoteCount) in iCloud")
                                        .font(PDFont.headlineSM)
                                        .foregroundStyle(Color.pdOnSurface)
                                    Text("\(confirmation.localCount) already on device")
                                        .font(PDFont.bodySM)
                                        .foregroundStyle(Color.pdOnSurfaceVariant)
                                }
                                Spacer()
                            }
                            Text("Apple downloads them securely through its built-in iCloud process before Pencil’d reads them on this device. Nothing leaves your device afterward.")
                                .font(PDFont.bodySM)
                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(spacing: 12) {
                        Button {
                            Task { await resolve(.downloadAll) }
                        } label: {
                            Label("Download all \(confirmation.remoteCount) from iCloud", systemImage: "arrow.down.circle.fill")
                        }
                        .buttonStyle(PDPrimaryButtonStyle())

                        Button {
                            Task { await resolve(.skipICloud) }
                        } label: {
                            Label("Skip iCloud item\(confirmation.remoteCount == 1 ? "" : "s")", systemImage: "icloud.slash")
                        }
                        .buttonStyle(PDSecondaryButtonStyle())

                        Button {
                            showPerPhoto = true
                        } label: {
                            Label("Choose which to download", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(PDSecondaryButtonStyle())
                    }
                    Text("Change this anytime in Settings › Scanning Options › iCloud & remote downloads.")
                        .font(PDFont.bodySM)
                        .foregroundStyle(Color.pdOnSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, PDSpacing.md)
                .padding(.top, PDSpacing.md)
                .padding(.bottom, 120)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .pdScreenBackground()
            .safeAreaInset(edge: .top, spacing: 0) {
                PDInterstitialHeader(closeLabel: "Cancel batch")
            }
            .sheet(isPresented: $showPerPhoto) {
                ICloudPhotoChooserView(confirmation: confirmation) { selectedIDs in
                    Task { await resolve(.perPhoto(selectedRemoteAssetIDs: selectedIDs)) }
                }
            }
        }
    }

    private func resolve(_ decision: ICloudBatchDecision) async {
        dismiss()
        await appState.resolveICloudBatch(decision)
    }
}

// MARK: - iCloud Per-Photo Chooser
/// Select-mode list of the iCloud-only sources in a batch. Each row has a checkbox (default
/// deselected); the user selects the ones to download, confirms, and the deselected items are
/// discarded. Mirrors the selection pattern used by `RecentScreenshotsView`.
struct ICloudPhotoChooserView: View {
    let confirmation: ICloudBatchConfirmation
    let onConfirm: (Set<String>) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String> = []

    private var remoteAssets: [(index: Int, asset: PHAsset)] {
        confirmation.plan.remote.enumerated().compactMap { index, source in
            guard case .asset(let asset) = source else { return nil }
            return (index, asset)
        }
    }

    private var allSelected: Bool {
        !remoteAssets.isEmpty && selected.count == remoteAssets.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PDSpacing.md) {
                    PDScreenIntro(
                        eyebrow: "iCloud Ingestion",
                        title: "Select what to download",
                        subtitle: "Only the iCloud items you check will be downloaded and scanned. Deselected items are discarded from this batch."
                    )
                    Button(allSelected ? "Deselect all" : "Select all") {
                        if allSelected { selected.removeAll() }
                        else { selected = Set(remoteAssets.map { $0.asset.localIdentifier }) }
                    }
                    .font(PDFont.labelLG)
                    .foregroundStyle(Color.pdPrimary)
                    .frame(minHeight: 44)

                    PDCard {
                        VStack(spacing: 0) {
                            ForEach(Array(remoteAssets), id: \.asset.localIdentifier) { entry in
                                let isSelected = selected.contains(entry.asset.localIdentifier)
                                Button {
                                    if isSelected { selected.remove(entry.asset.localIdentifier) }
                                    else { selected.insert(entry.asset.localIdentifier) }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(isSelected ? Color.pdPrimary : Color.pdOnSurfaceVariant)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Screenshot \(entry.index + 1)")
                                                .font(PDFont.labelLG)
                                                .foregroundStyle(Color.pdOnSurface)
                                            Text(entry.asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "iCloud-only")
                                                .font(PDFont.bodySM)
                                                .foregroundStyle(Color.pdOnSurfaceVariant)
                                        }
                                        Spacer()
                                        Image(systemName: "icloud")
                                            .foregroundStyle(Color.pdOnSurfaceVariant)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                                if entry.index < remoteAssets.count - 1 { PDRowDivider() }
                            }
                        }
                    }
                }
                .padding(.horizontal, PDSpacing.md)
                .padding(.top, PDSpacing.md)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .pdScreenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        onConfirm(selected)
                        dismiss()
                    }
                    .font(PDFont.labelLG)
                    .disabled(selected.isEmpty)
                }
            }
        }
    }
}

// MARK: - iCloud Single-Item Alert Modifier
/// Drives the `.alert` for `AppState.pendingICloudSingle`. Attached to the root view (see
/// `ContentView`) so the single-scan confirmation works from any screen that triggers one.
struct ICloudSingleAlertModifier: ViewModifier {
    @EnvironmentObject private var appState: AppState
    @AppStorage(ICloudDownloadPreference.key) private var preference = ICloudDownloadPreference.ask

    func body(content: Content) -> some View {
        content.alert(
            "Stored in iCloud",
            isPresented: Binding(
                get: { appState.pendingICloudSingle != nil },
                set: { if !$0 { clear() } }
            ),
            presenting: appState.pendingICloudSingle
        ) { item in
            Button("Download") {
                item.onDownload(true)
                clear()
            }
            Button("Skip", role: .cancel) {
                item.onDownload(false)
                clear()
            }
            Button("Skip all iCloud") {
                preference = .skip
                appState.showToast("iCloud-only items will be skipped. Change this anytime in Settings › Scanning Options.")
                item.onDownload(false)
                clear()
            }
        } message: { item in
            Text("This \(item.itemLabel) is stored in iCloud and isn't on this device. Download it through Apple's built-in process, or skip it. You can change this anytime in Settings.")
        }
    }

    private func clear() {
        appState.pendingICloudSingle = nil
    }
}

extension View {
    /// Presents the single-item iCloud confirmation alert from `AppState.pendingICloudSingle`.
    func iCloudSingleAlert() -> some View { modifier(ICloudSingleAlertModifier()) }
}
