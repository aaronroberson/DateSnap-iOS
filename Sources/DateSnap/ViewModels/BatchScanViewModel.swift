import Foundation
import SwiftUI
import UIKit
import Photos
import PhotosUI
import SwiftData

// MARK: - Batch Scan Source
/// One screenshot handed to the batch scanner: a loaded image, a photo-library asset
/// (fetched inside the pipeline), or a known load failure.
enum BatchScanSource: @unchecked Sendable {
    case loaded(id: String, image: UIImage)
    case asset(PHAsset)
    /// A `PhotosPicker` selection — image data is loaded when the batch reaches it.
    case photoPicker(PhotosPickerItem)
    case failed(reason: String)
}

// MARK: - Batch Scan Item
/// One screenshot in a multi-screenshot batch, with its pipeline outcome.
@MainActor
final class BatchScanItem: ObservableObject, Identifiable {
    enum Stage: Equatable {
        case pending
        case scanning
        case found(count: Int)
        case noDates
        case alreadySaved(count: Int)
        case failed(String)
    }

    let id = UUID()
    let label: String
    @Published private(set) var image: UIImage?
    @Published private(set) var stage: Stage = .pending
    @Published private(set) var candidates: [EventCandidate] = []

    init(label: String, image: UIImage? = nil) {
        self.label = label
        self.image = image
    }

    var isSuccess: Bool {
        if case .found = stage { return true }
        return false
    }

    var isResolved: Bool {
        switch stage {
        case .pending, .scanning: return false
        default: return true
        }
    }

    func begin() {
        stage = .scanning
    }

    /// Stores a bounded-size copy for thumbnails and the review header; the pipeline
    /// keeps the full-resolution image itself.
    func setDisplayImage(_ fullImage: UIImage?) {
        guard let fullImage else { return }
        let maxDimension: CGFloat = 1280
        let size = fullImage.size
        guard max(size.width, size.height) > maxDimension else {
            image = fullImage
            return
        }
        let scale = maxDimension / max(size.width, size.height)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: target)
        image = renderer.image { _ in
            fullImage.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func complete(candidates: [EventCandidate]) {
        self.candidates = candidates
        stage = candidates.isEmpty ? .noDates : .found(count: candidates.count)
    }

    func markAlreadySaved(_ count: Int) { stage = .alreadySaved(count: count) }

    func fail(_ message: String) { stage = .failed(message) }
}

// MARK: - Batch Scan View Model
/// Scans multiple screenshots sequentially through the shared on-device pipeline,
/// keeping each image's outcome separate so every found event can be reviewed —
/// and saved to its own calendar and reminders list — independently.
@MainActor
final class BatchScanViewModel: ObservableObject {
    @Published private(set) var items: [BatchScanItem] = []
    @Published private(set) var isProcessing = false
    /// The label of the screenshot currently being scanned ("Screenshot 2 of 5").
    @Published private(set) var currentLabel: String = ""

    private let services: ServiceContainer

    init(services: ServiceContainer) {
        self.services = services
    }

    static func label(forIndex index: Int) -> String { "Screenshot \(index)" }

    var foundItems: [BatchScanItem] { items.filter(\.isSuccess) }

    var totalEventCount: Int {
        items.reduce(0) { count, item in
            if case .found(let eventCount) = item.stage { return count + eventCount }
            return count
        }
    }

    /// Scans each source in order, updating per-item stages as it goes.
    /// A failure on one screenshot never stops the others.
    func scan(_ sources: [BatchScanSource], modelContext: ModelContext?) async {
        guard !sources.isEmpty, !isProcessing else { return }
        isProcessing = true
        items = sources.enumerated().map { BatchScanItem(label: Self.label(forIndex: $0.offset + 1)) }
        defer {
            isProcessing = false
            currentLabel = ""
        }

        // One shared pipeline instance; reset between images so each screenshot is independent.
        let scanner = ScanViewModel(services: services)

        for (item, source) in zip(items, sources) {
            currentLabel = item.label
            await scanOne(item, source: source, scanner: scanner, modelContext: modelContext)
        }
    }

    private func scanOne(
        _ item: BatchScanItem,
        source: BatchScanSource,
        scanner: ScanViewModel,
        modelContext: ModelContext?
    ) async {
        switch source {
        case .failed(let reason):
            item.fail(reason)
            return
        case .asset(let asset):
            item.begin()
            do {
                let image = try await services.photoLibrary.fetchImage(
                    for: asset,
                    targetSize: CGSize(width: 1440, height: 2560)
                )
                await runPipeline(item, image: image, assetIdentifier: asset.localIdentifier, scanner: scanner, modelContext: modelContext)
            } catch {
                item.fail("Could not load the screenshot: \(error.localizedDescription)")
            }
        case .loaded(let id, let image):
            item.begin()
            await runPipeline(item, image: image, assetIdentifier: id, scanner: scanner, modelContext: modelContext)
        case .photoPicker(let pickerItem):
            item.begin()
            do {
                guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                    item.fail("That photo could not be loaded.")
                    return
                }
                guard let image = UIImage(data: data) else {
                    item.fail("That photo could not be read as an image.")
                    return
                }
                await runPipeline(
                    item,
                    image: image,
                    assetIdentifier: pickerItem.itemIdentifier ?? UUID().uuidString,
                    scanner: scanner,
                    modelContext: modelContext
                )
            } catch {
                item.fail("Could not load the photo: \(error.localizedDescription)")
            }
        }
    }

    private func runPipeline(
        _ item: BatchScanItem,
        image: UIImage,
        assetIdentifier: String,
        scanner: ScanViewModel,
        modelContext: ModelContext?
    ) async {
        item.setDisplayImage(image)
        scanner.reset()
        await scanner.scanImage(image, assetIdentifier: assetIdentifier, modelContext: modelContext)
        switch scanner.stage {
        case .complete(let candidates):
            item.complete(candidates: candidates)
        case .noDatesFound:
            item.complete(candidates: [])
        case .alreadySaved(let count):
            item.markAlreadySaved(count)
        case .failed(let message):
            item.fail(message)
        case .idle, .fetchingImage, .processingOCR, .extractingEvents, .interpreting:
            item.fail("The scan ended unexpectedly.")
        }
    }
}

// MARK: - Batch Review Session
/// One event extracted from a batch scan. Each event owns an `EventReviewViewModel`,
/// so its calendar, reminders list, and alert schedule are chosen independently.
@MainActor
final class BatchEventItem: ObservableObject, Identifiable {
    enum Status: Equatable {
        case pending
        case saving
        case saved
        case failed(String)
    }

    let id = UUID()
    let candidate: EventCandidate
    let screenshotID: UUID
    let screenshotLabel: String
    let screenshotImage: UIImage?
    let review: EventReviewViewModel
    @Published var status: Status = .pending

    init(
        candidate: EventCandidate,
        screenshotID: UUID,
        screenshotLabel: String,
        screenshotImage: UIImage?,
        services: ServiceContainer
    ) {
        self.candidate = candidate
        self.screenshotID = screenshotID
        self.screenshotLabel = screenshotLabel
        self.screenshotImage = screenshotImage
        self.review = EventReviewViewModel(
            candidate: candidate,
            services: services,
            sourceImage: screenshotImage
        )
    }

    var isActionable: Bool {
        switch status {
        case .pending, .failed: return true
        case .saving, .saved: return false
        }
    }
}

/// What a "Save All" pass produced, for the summary line after committing.
struct BatchSaveSummary: Equatable {
    let savedCount: Int
    let failedMessages: [String]

    var isAllSaved: Bool { failedMessages.isEmpty && savedCount > 0 }
}

@MainActor
final class BatchReviewSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published private(set) var events: [BatchEventItem] = []
    /// Screenshots that produced no reviewable event (no dates, already saved, or failed).
    @Published private(set) var skipped: [BatchScanItem] = []
    @Published private(set) var isSaving = false
    @Published private(set) var lastSummary: BatchSaveSummary? = nil

    var actionableCount: Int { events.filter(\.isActionable).count }

    /// Builds the review session from a finished batch scan (production path).
    init(scan: BatchScanViewModel, services: ServiceContainer) {
        for item in scan.items {
            guard item.isSuccess else {
                skipped.append(item)
                continue
            }
            for candidate in item.candidates {
                events.append(BatchEventItem(
                    candidate: candidate,
                    screenshotID: item.id,
                    screenshotLabel: item.label,
                    screenshotImage: item.image,
                    services: services
                ))
            }
        }
    }

    /// Test/diagnostic path: a session built directly from events.
    init(events: [BatchEventItem]) {
        self.events = events
    }

    /// Requests Calendar & Reminders access once, then loads destination lists for every event.
    func prepareDestinations() async {
        guard let first = events.first else { return }
        await first.review.prepareDestinations()
        for event in events.dropFirst() {
            event.review.loadCalendarData()
        }
    }

    @discardableResult
    func saveAll(modelContext: ModelContext?) async -> BatchSaveSummary {
        guard !isSaving else {
            return lastSummary ?? BatchSaveSummary(savedCount: 0, failedMessages: ["A save is already in progress."])
        }
        isSaving = true
        defer { isSaving = false }

        var savedCount = 0
        var failures: [String] = []
        for event in events where event.isActionable {
            event.status = .saving
            let result = await event.review.commitEvent(modelContext: modelContext)
            switch result {
            case .success, .partial:
                // .partial means the Calendar write succeeded but Reminders/alerts had issues;
                // the event itself is committed, matching the single-review flow.
                event.status = .saved
                savedCount += 1
            case .failure(let error):
                event.status = .failed(error.message)
                failures.append("\(event.screenshotLabel): \(event.candidate.title) — \(error.message)")
            }
        }

        let summary = BatchSaveSummary(savedCount: savedCount, failedMessages: failures)
        lastSummary = summary
        return summary
    }

    /// Removes an unsaved event from the batch (and the review queue).
    @discardableResult
    func discard(_ event: BatchEventItem, modelContext: ModelContext?) -> Bool {
        guard event.isActionable else { return false }
        let result = event.review.discard(modelContext: modelContext)
        guard case .success = result else { return false }
        events.removeAll { $0.id == event.id }
        return true
    }
}
