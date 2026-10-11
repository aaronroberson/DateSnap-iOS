import Foundation
import Photos
import UIKit

// MARK: - Photo Candidate Ranker
/// Ranks recent screenshots by how likely they are to show an event. Works only on the existing recent
/// screenshot set, reads images locally (no network), and never scans the full library in the background.
enum PhotoCandidateRanker {
    /// How many unscanned screenshots get a quick OCR check per refresh.
    static let assessmentBudget = 6

    /// Deterministic ordering: likely events first, then unscanned, then newest.
    static func rank(_ assets: [PHAsset], scannedIDs: Set<String>, likelyEventIDs: Set<String>) -> [PHAsset] {
        assets.enumerated().sorted { lhs, rhs in
            let l = score(lhs.element, scanned: scannedIDs, likely: likelyEventIDs)
            let r = score(rhs.element, scanned: scannedIDs, likely: likelyEventIDs)
            return l == r ? lhs.offset < rhs.offset : l > r
        }.map(\.element)
    }

    private static func score(_ asset: PHAsset, scanned: Set<String>, likely: Set<String>) -> Int {
        (likely.contains(asset.localIdentifier) ? 2 : 0) + (scanned.contains(asset.localIdentifier) ? 0 : 1)
    }

    /// Quick local check: small image → Vision OCR → deterministic scan-worthiness (date/time cues, not a receipt).
    static func isLikelyEvent(
        _ asset: PHAsset,
        photos: PhotoLibraryServiceProtocol,
        ocr: OCRServiceProtocol,
        now: Date = Date()
    ) async -> Bool {
        guard let image = try? await photos.fetchImage(for: asset, targetSize: CGSize(width: 720, height: 1280)),
              let result = try? await ocr.recognizeLines(in: image, confidenceFloor: 0.3) else { return false }
        return RuleBasedEventAnalyzer.qualityReport(for: result, anchor: now).isScanWorthy
    }
}
