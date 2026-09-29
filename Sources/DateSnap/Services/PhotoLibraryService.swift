import Foundation
import Photos
import UIKit

// MARK: - PhotoLibrary Service Protocol
public protocol PhotoLibraryServiceProtocol: Sendable {
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus
    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset]
    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
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
        guard currentStatus == .authorized || currentStatus == .limited else {
            throw DateSnapError.photoLibrary(.accessDenied)
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum,
                    subtype: .smartAlbumScreenshots,
                    options: nil
                )

                guard let screenshotsAlbum = collections.firstObject else {
                    continuation.resume(throwing: DateSnapError.photoLibrary(.smartAlbumNotFound))
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
    public func fetchImage(for asset: PHAsset, targetSize: CGSize = CGSize(width: 1440, height: 2560)) async throws -> UIImage {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false // 100% on-device local rule
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        return try await withCheckedThrowingContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    // Wait for full resolution
                    return
                }

                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: DateSnapError.photoLibrary(.imageConversionFailed))
                }
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
