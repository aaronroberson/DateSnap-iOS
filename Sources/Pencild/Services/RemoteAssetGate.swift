import Foundation
import Photos

// MARK: - iCloud Download Preference

/// The user's choice for how Pencil'd handles assets whose original is only in iCloud (Photos or
/// iCloud Drive). Pencil'd only scans on-device assets by default; an iCloud download is an
/// explicit opt-in so the "100% on-device" privacy claim stays honest. Stored in `@AppStorage`
/// (`settings.iCloudDownloadPreference`), default `.ask`.
enum ICloudDownloadPreference: String, CaseIterable, Sendable {
    /// Prompt before downloading each batch's iCloud-only assets (default).
    case ask
    /// Download iCloud-only assets through Apple's built-in process without asking.
    case allow
    /// Never download; skip iCloud-only assets with a clear message.
    case skip

    static let key = "settings.iCloudDownloadPreference"

    /// The current persisted preference (`.ask` when unset).
    static var standard: ICloudDownloadPreference {
        UserDefaults.standard.string(forKey: key).flatMap(ICloudDownloadPreference.init(rawValue:)) ?? .ask
    }

    var displayName: String {
        switch self {
        case .ask: return "Ask before downloading"
        case .allow: return "Allow iCloud downloads"
        case .skip: return "Skip iCloud-only items"
        }
    }
}

// MARK: - Remote Asset Plan

/// A batch partitioned into on-device and iCloud-only sources. The iCloud-only sources are the ones
/// `RemoteAssetGate` flagged as not fully present locally; the user decides (via the preference or
/// the confirmation sheet) whether to download them, skip them, or pick per-photo.
struct RemoteAssetPlan: Sendable {
    let local: [BatchScanSource]
    let remote: [BatchScanSource]

    init(local: [BatchScanSource], remote: [BatchScanSource]) {
        self.local = local
        self.remote = remote
    }
}

// MARK: - Remote Asset Gate

/// Pure preflight that splits a batch into on-device vs iCloud-only sources, and probes whether a
/// Files/iCloud Drive URL is downloaded locally. Used by `AppState.requestBatchScan` and the
/// single-document path to decide whether to prompt the user before any download happens.
enum RemoteAssetGate {
    /// Splits `sources` into local vs iCloud-only. Only `.asset(PHAsset)` sources can be probed
    /// cheaply (`PHImageResultIsInCloudKey`); `.photoPicker`, `.loaded`, and `.failed` are treated
    /// as local because `PhotosPickerItem` exposes no cloud-state API and `loaded` images are
    /// already in memory.
    static func partition(
        _ sources: [BatchScanSource],
        photos: PhotoLibraryServiceProtocol
    ) async -> RemoteAssetPlan {
        var local: [BatchScanSource] = []
        var remote: [BatchScanSource] = []
        for source in sources {
            switch source {
            case .asset(let asset):
                if await photos.isInCloud(for: asset) {
                    remote.append(source)
                } else {
                    local.append(source)
                }
            case .photoPicker, .loaded, .failed:
                local.append(source)
            }
        }
        return RemoteAssetPlan(local: local, remote: remote)
    }

    /// `true` when `url` points at an iCloud Drive item that is not fully downloaded to this device.
    /// Non-ubiquitous URLs (e.g. picked from the local Documents folder) return `true` (treated as
    /// downloaded). Used by the Files/PDF import path so the same preference + confirmation applies.
    static func isFileDownloadedLocally(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey, .isUbiquitousItemKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return true }
        // Not an iCloud Drive file → it's already on disk.
        guard values.isUbiquitousItem == true else { return true }
        // Ubiquitous: downloaded only when the status is `.current`.
        let status = values.ubiquitousItemDownloadingStatus
        return status == .current
    }

    /// Requests an iCloud Drive download for `url` (no-op if already local) and waits until the
    /// download completes or `timeout` elapses. Returns `false` on timeout/failure so the caller
    /// can surface `.fileDownloadFailed`.
    static func downloadUbiquitousFile(
        _ url: URL,
        fileManager: FileManager = .default,
        timeout: TimeInterval = 30
    ) async -> Bool {
        guard isFileDownloadedLocally(url, fileManager: fileManager) == false else { return true }
        try? fileManager.startDownloadingUbiquitousItem(at: url)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return false }
            if isFileDownloadedLocally(url, fileManager: fileManager) { return true }
        }
        return false
    }
}

// MARK: - iCloud Gate Decision

/// What the gate decided after consulting the preference for a batch that has `remoteCount` iCloud
/// items. `.ask` means the caller should present the confirmation sheet.
enum ICloudGateDecision: Sendable, Equatable {
    case proceed(allowICloudDownload: Bool)
    case skipRemotes
    case ask
}

extension RemoteAssetGate {
    /// Resolves a batch against `ICloudDownloadPreference`. `.ask` only when the preference is
    /// `.ask` and there's at least one remote source; otherwise the preference decides outright.
    static func decide(remoteCount: Int, preference: ICloudDownloadPreference) -> ICloudGateDecision {
        guard remoteCount > 0 else { return .proceed(allowICloudDownload: false) }
        switch preference {
        case .allow: return .proceed(allowICloudDownload: true)
        case .skip: return .skipRemotes
        case .ask: return .ask
        }
    }
}
