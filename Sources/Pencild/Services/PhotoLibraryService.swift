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
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        // Pencil'd only scans on-device assets by default. iCloud downloads are an explicit opt-in
        // (see `ICloudDownloadPreference`), so the network is enabled only when the user approved it.
        options.isNetworkAccessAllowed = allowICloudDownload
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        // `.fast` resizes before decoding so a 360×640 thumbnail request never decodes the full
        // screenshot original — the previous default could decode multi-megapixel images for a
        // small preview, a major source of jank during scrolling.
        options.resizeMode = .fast

        // Forward iCloud download progress when a callback was provided. `PHAssetImageProgressHandler`
        // bridges to `(Double, Error?, UnsafeMutablePointer<ObjCBool>?, [AnyHashable: Any]?) -> Void`.
        if let progress {
            let forward: (Double) -> Void = progress
            let handler: (Double, Error?, UnsafeMutablePointer<ObjCBool>?, [AnyHashable: Any]?) -> Void = { value, _, _, _ in
                forward(value)
            }
            options.progressHandler = handler
        }

        // Cancelling the Swift task (a thumbnail scrolled off screen, a cancelled scan) cancels the
        // Photos request too, so stale decodes and iCloud downloads don't pile up.
        let request = ImageRequestGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, any Error>) in
                request.install(continuation)
                let requestID = imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, info in
                    if (info?[PHImageCancelledKey] as? Bool) == true {
                        request.finish(.failure(CancellationError()))
                        return
                    }
                    let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                    let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                    if let image {
                        // Accept a degraded image rather than hang; the gate drops the later final one.
                        request.finish(.success(image))
                    } else if isInCloud && !allowICloudDownload {
                        request.finish(.failure(PencildError.photoLibrary(.iCloudDownloadRequired)))
                    } else if isDegraded && !allowICloudDownload {
                        // Offline, Photos can send a blank degraded frame and never a final one for an
                        // iCloud-only original, so waiting for a final frame would hang the scan.
                        request.finish(.failure(PencildError.photoLibrary(.iCloudDownloadRequired)))
                    } else if isDegraded {
                        // Downloading: a blank degraded frame comes before the downloaded image.
                        return
                    } else if allowICloudDownload {
                        // Network access was allowed but the image still came back nil: the iCloud
                        // download failed or was interrupted.
                        let reason = (info?[PHImageErrorKey] as? NSError)?.localizedDescription ?? "The download didn't complete."
                        request.finish(.failure(PencildError.photoLibrary(.iCloudDownloadFailed(reason))))
                    } else {
                        request.finish(.failure(PencildError.photoLibrary(.imageConversionFailed)))
                    }
                }
                request.setRequestID(requestID)

                // Backstop: never leave a scan or thumbnail waiting forever on Photos.
                let limit = allowICloudDownload ? Self.downloadTimeout : Self.localTimeout
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + limit) {
                    if let expiredID = request.expire() {
                        PHImageManager.default().cancelImageRequest(expiredID)
                    }
                }
            }
        } onCancel: {
            if let requestID = request.cancel() {
                PHImageManager.default().cancelImageRequest(requestID)
            }
        }
    }

    // MARK: - iCloud cloud-state probe
    public func isInCloud(for asset: PHAsset) async -> Bool {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isSynchronous = false
        // A tiny target keeps the probe cheap even for a 30-asset batch preflight.
        let probeSize = CGSize(width: 8, height: 8)

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            imageManager.requestImage(
                for: asset,
                targetSize: probeSize,
                contentMode: .aspectFit,
                options: options
            ) { _, info in
                guard !hasResumed else { return }
                hasResumed = true
                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                continuation.resume(returning: isInCloud)
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
