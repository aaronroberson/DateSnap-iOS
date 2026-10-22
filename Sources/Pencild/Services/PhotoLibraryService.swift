import Foundation
import Photos
import UIKit

// MARK: - PhotoLibrary Service Protocol
public protocol PhotoLibraryServiceProtocol: Sendable {
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset]
    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
    /// Fetches a full-resolution image for `asset`. When `allowICloudDownload` is false (default),
    /// an iCloud-only asset throws `.iCloudDownloadRequired` rather than silently downloading it —
    /// Pencil'd only scans on-device assets unless the user has opted in. `progress` receives 0…1
    /// download progress when an iCloud fetch is in flight.
    func fetchImage(for asset: PHAsset, targetSize: CGSize, allowICloudDownload: Bool, progress: (@Sendable (Double) -> Void)?) async throws -> UIImage
    /// Cheap cloud-state probe: `true` when the asset's original is only in iCloud and not stored
    /// locally. Used by `RemoteAssetGate` to decide whether to ask the user before scanning.
    func isInCloud(for asset: PHAsset) async -> Bool
    func observeLibraryChanges() -> AsyncStream<Void>
}

// MARK: - Production PhotoLibrary Service
public final class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let lock = NSLock()
    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    private var isObserverRegistered = false

    public override init() {
        super.init()
    }

    deinit {
        if isObserverRegistered {
            PHPhotoLibrary.shared().unregisterChangeObserver(self)
        }
    }

    // MARK: - Progressive Permissions
    public func requestAuthorization(for accessLevel: PHAccessLevel = .readWrite) async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: accessLevel) { status in
                continuation.resume(returning: status)
            }
        }
    }

    public func authorizationStatus(for accessLevel: PHAccessLevel = .readWrite) -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: accessLevel)
    }

    // MARK: - Fetch Recent Screenshots
    public func fetchRecentScreenshots(limit: Int = 20) async throws -> [PHAsset] {
        let currentStatus = authorizationStatus(for: .readWrite)
        guard currentStatus.access.isUsable else {
            throw PencildError.photoLibrary(.accessDenied)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .smartAlbumScreenshots,
                    options: nil
                )

                guard let screenshotsAlbum = collections.firstObject else {
                    continuation.resume(throwing: PencildError.photoLibrary(.smartAlbumNotFound))
                    return
                }

                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = limit

                let assetsFetchResult = PHAsset.fetchAssets(in: screenshotsAlbum, options: fetchOptions)
                var assets: [PHAsset] = []
                assetsFetchResult.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }

                continuation.resume(returning: assets)
            }
        }
    }

    // MARK: - Fetch UIImage for PHAsset
    /// How long an on-device image request may take before it fails instead of hanging.
    static let localTimeout: TimeInterval = 15
    /// How long a user-approved iCloud download may take.
    static let downloadTimeout: TimeInterval = 120

    public func fetchImage(for asset: PHAsset, targetSize: CGSize = CGSize(width: 1440, height: 2560)) async throws -> UIImage {
        try await fetchImage(for: asset, targetSize: targetSize, allowICloudDownload: false, progress: nil)
    }

    public func fetchImage(
        for asset: PHAsset,
        targetSize: CGSize = CGSize(width: 1440, height: 2560),
        allowICloudDownload: Bool,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> UIImage {
        print("[Pencild-Photo] Starting fetchImage for asset \(asset.localIdentifier), allowICloudDownload: \(allowICloudDownload)")
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = allowICloudDownload
        options.isSynchronous = false
        options.version = .current

        if let progress {
            let forward: (Double) -> Void = progress
            let handler: (Double, Error?, UnsafeMutablePointer<ObjCBool>?, [AnyHashable: Any]?) -> Void = { value, _, _, _ in
                forward(value)
            }
            options.progressHandler = handler
        }

        return try await withCheckedThrowingContinuation { continuation in
            let stateLock = NSLock()
            var hasResumed = false
            var activeRequestID: PHImageRequestID?

            let requestID = imageManager.requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, dataUTI, orientation, info in
                stateLock.lock()
                guard !hasResumed else {
                    stateLock.unlock()
                    return
                }
                hasResumed = true
                stateLock.unlock()

                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                let error = info?[PHImageErrorKey] as? Error
                print("[Pencild-Photo] requestImageData callback: bytes=\(data?.count ?? 0), isInCloud=\(isInCloud), cancelled=\(isCancelled), error=\(String(describing: error))")

                if isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                if let data, var image = UIImage(data: data) {
                    if let cgImage = image.cgImage, orientation != .up {
                        image = UIImage(cgImage: cgImage, scale: image.scale, orientation: orientation.uiOrientation)
                    }
                    print("[Pencild-Photo] Resuming continuation with loaded full-resolution image: \(image.size)")
                    continuation.resume(returning: image)
                } else if isInCloud && !allowICloudDownload {
                    continuation.resume(throwing: PencildError.photoLibrary(.iCloudDownloadRequired))
                } else if allowICloudDownload, let error {
                    continuation.resume(throwing: PencildError.photoLibrary(.iCloudDownloadFailed(error.localizedDescription)))
                } else {
                    continuation.resume(throwing: PencildError.photoLibrary(.imageConversionFailed))
                }
            }

            stateLock.lock()
            activeRequestID = requestID
            stateLock.unlock()

            let limit = allowICloudDownload ? Self.downloadTimeout : Self.localTimeout
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + limit) {
                stateLock.lock()
                guard !hasResumed else {
                    stateLock.unlock()
                    return
                }
                hasResumed = true
                let idToCancel = activeRequestID
                stateLock.unlock()

                if let idToCancel {
                    PHImageManager.default().cancelImageRequest(idToCancel)
                }
                continuation.resume(throwing: PencildError.photoLibrary(.imageLoadTimedOut))
            }
        }
    }

    // MARK: - iCloud cloud-state probe
    public func isInCloud(for asset: PHAsset) async -> Bool {
        print("[Pencild-Photo] Probing isInCloud for asset \(asset.localIdentifier)")
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        // A tiny target keeps the probe cheap even for a 30-asset batch preflight.
        let probeSize = CGSize(width: 8, height: 8)

        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var hasResumed = false
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: probeSize,
                contentMode: .aspectFit,
                options: options
            ) { _, info in
                lock.lock()
                guard !hasResumed else {
                    lock.unlock()
                    return
                }
                hasResumed = true
                lock.unlock()
                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                print("[Pencild-Photo] isInCloud probe result for \(asset.localIdentifier): \(isInCloud)")
                continuation.resume(returning: isInCloud)
            }

            // Failsafe: probe must never block longer than 1.5s
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                lock.lock()
                guard !hasResumed else {
                    lock.unlock()
                    return
                }
                hasResumed = true
                lock.unlock()
                PHImageManager.default().cancelImageRequest(requestID)
                print("[Pencild-Photo] isInCloud probe timed out for \(asset.localIdentifier), defaulting to false")
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - Observe Library Changes
    public func observeLibraryChanges() -> AsyncStream<Void> {
        let id = UUID()
        return AsyncStream { continuation in
            lock.lock()
            if !isObserverRegistered {
                PHPhotoLibrary.shared().register(self)
                isObserverRegistered = true
            }
            changeContinuations[id] = continuation
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                self.changeContinuations.removeValue(forKey: id)
                if self.changeContinuations.isEmpty && self.isObserverRegistered {
                    PHPhotoLibrary.shared().unregisterChangeObserver(self)
                    self.isObserverRegistered = false
                }
                self.lock.unlock()
            }
        }
    }

    // MARK: - PHPhotoLibraryChangeObserver
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        lock.lock()
        let continuations = Array(changeContinuations.values)
        lock.unlock()

        for continuation in continuations {
            continuation.yield(())
        }
    }
}

// MARK: - Image Request Gate

/// Resume-once bookkeeping for `fetchImage`. Photos can call back twice (degraded, then final) and
/// task cancellation can race the callback; only the first outcome resumes the continuation.
final class ImageRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<UIImage, any Error>?
    private var requestID: PHImageRequestID?
    private var isCancelled = false
    private var isFinished = false

    func install(_ continuation: CheckedContinuation<UIImage, any Error>) {
        lock.lock()
        if isCancelled || isFinished {
            let wasCancelled = isCancelled && !isFinished
            isFinished = true
            lock.unlock()
            if wasCancelled { continuation.resume(throwing: CancellationError()) }
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func setRequestID(_ id: PHImageRequestID) {
        lock.lock()
        // Cancelled before Photos handed back an ID: cancel the request now.
        let cancelNow = isCancelled
        requestID = id
        lock.unlock()
        if cancelNow {
            PHImageManager.default().cancelImageRequest(id)
        }
    }

    /// Marks the request cancelled; returns its ID if Photos already issued one.
    func cancel() -> PHImageRequestID? {
        lock.lock()
        isCancelled = true
        let id = requestID
        lock.unlock()
        finish(.failure(CancellationError()))
        return id
    }

    /// Fails a request that never finished. Returns its Photos request ID so it can be cancelled.
    func expire() -> PHImageRequestID? {
        lock.lock()
        let pending = !isFinished
        let id = requestID
        lock.unlock()
        guard pending else { return nil }
        finish(.failure(PencildError.photoLibrary(.imageLoadTimedOut)))
        return id
    }

    func finish(_ result: Result<UIImage, any Error>) {
        lock.lock()
        guard !isFinished, let continuation else {
            lock.unlock()
            return
        }
        isFinished = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
// MARK: - CGImagePropertyOrientation Helper
extension CGImagePropertyOrientation {
    var uiOrientation: UIImage.Orientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

