import Foundation
import Testing
import Photos
import UIKit
@testable import Pencild

@Suite("Remote Asset Gate Tests")
struct RemoteAssetGateTests {

    // MARK: - Decision Logic

    @Test("decide returns proceed-allow=false when no remote sources")
    func decideNoRemotes() {
        let decision = RemoteAssetGate.decide(remoteCount: 0, preference: .allow)
        #expect(decision == .proceed(allowICloudDownload: false))
    }

    @Test("decide with .allow preference downloads")
    func decideAllow() {
        let decision = RemoteAssetGate.decide(remoteCount: 3, preference: .allow)
        #expect(decision == .proceed(allowICloudDownload: true))
    }

    @Test("decide with .skip preference skips remotes")
    func decideSkip() {
        let decision = RemoteAssetGate.decide(remoteCount: 3, preference: .skip)
        #expect(decision == .skipRemotes)
    }

    @Test("decide with .ask preference asks when remotes exist")
    func decideAsk() {
        let decision = RemoteAssetGate.decide(remoteCount: 1, preference: .ask)
        #expect(decision == .ask)
    }

    @Test("decide .ask with zero remotes proceeds without download")
    func decideAskNoRemotes() {
        let decision = RemoteAssetGate.decide(remoteCount: 0, preference: .ask)
        #expect(decision == .proceed(allowICloudDownload: false))
    }

    // MARK: - Partition (stubbed photo service)

    @Test("partition splits .asset sources by isInCloud, treats photoPicker/loaded/failed as local")
    func partitionSplitsAssets() async {
        let remoteAsset = FakeAsset()
        let localAsset = FakeAsset()
        let photos = StubPhotoLibrary(remoteAssetIDs: Set([remoteAsset.localIdentifier]))
        let sources: [BatchScanSource] = [
            .asset(remoteAsset),
            .asset(localAsset),
            .loaded(id: "loaded-1", image: UIImage()),
            .failed(reason: "boom")
        ]
        let plan = await RemoteAssetGate.partition(sources, photos: photos)
        #expect(plan.remote.count == 1)
        #expect(plan.local.count == 3)
        if case .asset(let asset) = plan.remote[0] {
            #expect(asset.localIdentifier == remoteAsset.localIdentifier)
        } else {
            Issue.record("remote source should be the in-cloud asset")
        }
    }

    @Test("partition with no .asset sources keeps everything local")
    func partitionNoAssets() async {
        let photos = StubPhotoLibrary(remoteAssetIDs: [])
        let sources: [BatchScanSource] = [
            .loaded(id: "a", image: UIImage()),
            .failed(reason: "x")
        ]
        let plan = await RemoteAssetGate.partition(sources, photos: photos)
        #expect(plan.remote.isEmpty)
        #expect(plan.local.count == 2)
    }
}

// MARK: - ICloud Batch Decision Resolution
// These tests exercise `ICloudBatchDecision.resolvedSources(for:)` directly, which only needs the
// `RemoteAssetPlan` carried by `ICloudBatchConfirmation`. `ServiceContainer`/`modelContext` are
// left nil — `resolvedSources` never touches them.
@Suite("ICloud Batch Decision Resolution Tests")
struct ICloudBatchDecisionTests {
    @Test(".downloadAll keeps all sources and enables download")
    func downloadAll() {
        let (confirmation, remoteIDs) = makeConfirmation(localCount: 2, remoteCount: 3)
        let resolved = ICloudBatchDecision.downloadAll.resolvedSources(for: confirmation)
        #expect(resolved.sources.count == 5)
        #expect(resolved.allowICloudDownload == true)
        _ = remoteIDs
    }

    @Test(".skipICloud keeps only local sources and disables download")
    func skipICloud() {
        let (confirmation, _) = makeConfirmation(localCount: 2, remoteCount: 3)
        let resolved = ICloudBatchDecision.skipICloud.resolvedSources(for: confirmation)
        #expect(resolved.sources.count == 2)
        #expect(resolved.allowICloudDownload == false)
    }

    @Test(".perPhoto keeps local plus only the selected remote assets")
    func perPhotoSelection() {
        let (confirmation, remoteIDs) = makeConfirmation(localCount: 1, remoteCount: 3)
        let selected: Set<String> = Set([remoteIDs[0], remoteIDs[2]])
        let resolved = ICloudBatchDecision.perPhoto(selectedRemoteAssetIDs: selected).resolvedSources(for: confirmation)
        #expect(resolved.sources.count == 3) // 1 local + 2 chosen remotes
        #expect(resolved.allowICloudDownload == true)
    }

    @Test(".perPhoto with no selection keeps only local")
    func perPhotoNoneSelected() {
        let (confirmation, _) = makeConfirmation(localCount: 2, remoteCount: 3)
        let resolved = ICloudBatchDecision.perPhoto(selectedRemoteAssetIDs: []).resolvedSources(for: confirmation)
        #expect(resolved.sources.count == 2)
        #expect(resolved.allowICloudDownload == true)
    }

    /// Builds a confirmation with synthetic `.asset` remotes and `.loaded` locals, returning the
    /// confirmation plus the remote asset localIdentifiers so the test can pick a subset.
    private func makeConfirmation(localCount: Int, remoteCount: Int) -> (ICloudBatchConfirmation, [String]) {
        let local: [BatchScanSource] = (0..<localCount).map { .loaded(id: "local-\($0)", image: UIImage()) }
        let remoteAssets = (0..<remoteCount).map { _ in FakeAsset() }
        let remote: [BatchScanSource] = remoteAssets.map { .asset($0) }
        let plan = RemoteAssetPlan(local: local, remote: remote)
        let confirmation = ICloudBatchConfirmation(
            sources: local + remote,
            plan: plan,
            services: nil,
            modelContext: nil
        )
        return (confirmation, remoteAssets.map(\.localIdentifier))
    }
}

// MARK: - Stubs

private final class StubPhotoLibrary: PhotoLibraryServiceProtocol, @unchecked Sendable {
    let remoteAssetIDs: Set<String>
    init(remoteAssetIDs: Set<String>) { self.remoteAssetIDs = remoteAssetIDs }
    func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus { .authorized }
    func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .authorized }
    func fetchRecentScreenshots(limit: Int) async throws -> [PHAsset] { [] }
    func fetchImage(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage { UIImage() }
    func fetchImage(for asset: PHAsset, targetSize: CGSize, allowICloudDownload: Bool, progress: (@Sendable (Double) -> Void)?) async throws -> UIImage { UIImage() }
    func isInCloud(for asset: PHAsset) async -> Bool { remoteAssetIDs.contains(asset.localIdentifier) }
    func observeLibraryChanges() -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}

/// `PHAsset()` instances all share an empty `localIdentifier`; tests need distinct ones.
private final class FakeAsset: PHAsset, @unchecked Sendable {
    private let fakeID = UUID().uuidString
    override var localIdentifier: String { fakeID }
}
