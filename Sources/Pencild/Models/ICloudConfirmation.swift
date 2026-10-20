import Foundation
import SwiftData

// MARK: - iCloud Batch Confirmation

/// A batch that contains iCloud-only sources, held on `AppState.pendingICloudBatch` while the user
/// decides whether to download them, skip them, or choose per-photo. Presented as a sheet by
/// `ContentView` via `ICloudBatchConfirmationView`.
struct ICloudBatchConfirmation: Identifiable {
    let id = UUID()
    /// The full set of sources the user originally asked to scan.
    let sources: [BatchScanSource]
    /// The preflight split: `local` are on-device, `remote` are iCloud-only.
    let plan: RemoteAssetPlan
    /// The services the batch should run with once a decision is reached. Optional only so tests can
    /// build a confirmation without a live `ServiceContainer`; production always sets it.
    let services: ServiceContainer?
    /// The model context for the eventual scan.
    let modelContext: ModelContext?
}

extension ICloudBatchConfirmation {
    var remoteCount: Int { plan.remote.count }
    var totalCount: Int { sources.count }
    var localCount: Int { plan.local.count }
}

// MARK: - iCloud Batch Decision

/// What the user chose on the iCloud batch confirmation sheet.
enum ICloudBatchDecision: Sendable, Equatable {
    /// Download every iCloud-only source and scan the whole batch.
    case downloadAll
    /// Discard the iCloud-only sources and scan only the on-device ones.
    case skipICloud
    /// Download exactly the remote sources whose IDs are in `selectedRemoteAssetIDs`, discard the
    /// rest of the remote sources, and scan the whole on-device set plus the chosen downloads.
    case perPhoto(selectedRemoteAssetIDs: Set<String>)
}

// MARK: - iCloud Single Confirmation

/// One iCloud-only asset (a Photo or a Files/PDF item) awaiting the user's download decision,
/// surfaced as an alert by the view that initiated the scan. Carries the closure that runs the
/// scan once the user decides, so the view does not need to keep its own pending state.
struct ICloudSingleConfirmation: Identifiable {
    let id = UUID()
    /// What the alert calls the item — "screenshot", "PDF", "file" — so the copy reads naturally.
    let itemLabel: String
    /// Runs the deferred scan. `true` when the user approved an iCloud download (or already allowed
    /// it via preference), `false` when they chose to skip this one.
    var onDownload: (Bool) -> Void
}

// MARK: - Decision Resolution Helpers

extension ICloudBatchDecision {
    /// Builds the final source list and the `allowICloudDownload` flag for the batch scanner from a
    /// decision and the originating confirmation.
    func resolvedSources(for confirmation: ICloudBatchConfirmation) -> (sources: [BatchScanSource], allowICloudDownload: Bool) {
        switch self {
        case .downloadAll:
            return (confirmation.sources, true)
        case .skipICloud:
            return (confirmation.plan.local, false)
        case .perPhoto(let selected):
            // Match each remote source by its asset's localIdentifier; only chosen ones are kept.
            let chosenRemotes = confirmation.plan.remote.filter { source in
                guard case .asset(let asset) = source else { return false }
                return selected.contains(asset.localIdentifier)
            }
            return (confirmation.plan.local + chosenRemotes, true)
        }
    }
}

// MARK: - iCloud Single Decision

/// What the user chose on the single-item iCloud alert.
enum ICloudSingleDecision: Sendable {
    /// Download this item (and scan it).
    case download
    /// Skip this one item only.
    case skip
    /// Skip this item and set the sticky preference to `.skip` so future iCloud items are skipped.
    case skipAll
}
