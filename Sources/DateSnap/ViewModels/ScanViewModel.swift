import Foundation
import SwiftUI
import Photos
import PDFKit
import SwiftData
import UniformTypeIdentifiers

@MainActor
public final class ScanViewModel: ObservableObject {
    private let photoLibraryService: PhotoLibraryServiceProtocol
    private let ocrService: OCRServiceProtocol
    private let understanding: EventUnderstandingProviding

    // MARK: - Pipeline State
    public enum ScanStage: Equatable {
        case idle
        case fetchingImage
        case processingOCR
        case extractingEvents
        /// The on-device model is interpreting the text (only when it will actually run).
        case interpreting
        case complete(candidates: [EventCandidate])
        case noDatesFound(rawText: String)
        /// Every detected event is already saved in History.
        case alreadySaved(count: Int)
        case failed(String)

        public static func == (lhs: ScanStage, rhs: ScanStage) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.fetchingImage, .fetchingImage), (.processingOCR, .processingOCR), (.extractingEvents, .extractingEvents), (.interpreting, .interpreting):
                return true
            case (.complete(let a), .complete(let b)):
                return a.map(\.id) == b.map(\.id)
            case (.noDatesFound(let a), .noDatesFound(let b)):
                return a == b
            case (.alreadySaved(let a), .alreadySaved(let b)):
                return a == b
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    @Published public var stage: ScanStage = .idle
    @Published public var rawOcrText: String = ""
    @Published public var ocrConfidence: Float = 0.0
    @Published public var extractedCandidates: [EventCandidate] = []
    @Published public var currentProcessingImage: UIImage? = nil
    @Published public var isProcessing: Bool = false
    /// Page progress for multi-page documents ("Page 2 of 5").
    @Published public var progressDetail: String? = nil
    /// Review bundle (best interpretation, alternatives, evidence) per candidate ID from the last scan.
    @Published public var understandingByCandidateID: [String: EventUnderstanding] = [:]
    /// Route, quality and evidence lines of the last scan (combined across PDF pages).
    @Published public var lastResult: EventUnderstandingResult? = nil
    /// The in-flight on-device interpretation, cancellable from the progress overlay.
    private var interpretationTask: Task<EventUnderstandingResult, Never>? = nil

    public init(services: ServiceContainer) {
        self.photoLibraryService = services.photoLibrary
        self.ocrService = services.ocr
        self.understanding = services.understanding
    }

    // MARK: - Scan PHAsset Pipeline
    public func scanAsset(_ asset: PHAsset, modelContext: ModelContext? = nil) async {
        isProcessing = true
        stage = .fetchingImage

        do {
            let image = try await photoLibraryService.fetchImage(for: asset, targetSize: CGSize(width: 1440, height: 2560))
            self.currentProcessingImage = image
            await scanImage(image, assetIdentifier: asset.localIdentifier, modelContext: modelContext)
        } catch {
            stage = .failed(error.localizedDescription)
            isProcessing = false
        }
    }

    // MARK: - Scan UIImage Pipeline (Manual import / Picker / Sample)
    public func scanImage(_ image: UIImage, assetIdentifier: String = UUID().uuidString, modelContext: ModelContext? = nil) async {
        await scanPages([image], assetIdentifier: assetIdentifier, modelContext: modelContext)
    }

    /// Scans raw image data (from `PhotosPicker` or the Files importer).
    public func scanImageData(_ data: Data, assetIdentifier: String = UUID().uuidString, modelContext: ModelContext? = nil) async {
        guard let image = UIImage(data: data) else {
            stage = .failed(DateSnapError.photoLibrary(.imageConversionFailed).localizedDescription)
            return
        }
        await scanImage(image, assetIdentifier: assetIdentifier, modelContext: modelContext)
    }

    /// Scans the bundled-at-runtime sample flyer; needs no photo permissions.
    public func scanSampleFlyer(modelContext: ModelContext? = nil) async {
        await scanImage(SampleFlyer.render(), assetIdentifier: "datesnap-sample-flyer", modelContext: modelContext)
    }

    // MARK: - Files / PDF Import Pipeline (Premium)
    /// Scans a PDF (every page) or an image file picked from Files / iCloud Drive.
    public func scanDocument(at url: URL, modelContext: ModelContext? = nil) async {
        isProcessing = true
        stage = .fetchingImage
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let type = UTType(filenameExtension: url.pathExtension)
        if type?.conforms(to: .pdf) == true {
            guard let document = PDFDocument(url: url), document.pageCount > 0 else {
                stage = .failed("This PDF could not be opened.")
                isProcessing = false
                return
            }
            let pages = (0..<min(document.pageCount, 30)).compactMap { document.page(at: $0) }.map(Self.render(page:))
            await scanPages(pages, assetIdentifier: "file:\(url.lastPathComponent)", modelContext: modelContext)
        } else {
            guard let data = try? Data(contentsOf: url) else {
                stage = .failed("This file could not be read.")
                isProcessing = false
                return
            }
            await scanImageData(data, assetIdentifier: "file:\(url.lastPathComponent)", modelContext: modelContext)
        }
    }

    private static func render(page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale = max(1, 1700 / max(bounds.width, 1))
        return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
    }

    // MARK: - Shared OCR → Extraction → Dedupe Pipeline
    private func scanPages(_ pages: [UIImage], assetIdentifier: String, modelContext: ModelContext?) async {
        isProcessing = true
        currentProcessingImage = pages.first
        defer {
            isProcessing = false
            progressDetail = nil
        }

        // Let the on-device model load while Vision reads the text.
        let understanding = self.understanding
        Task.detached(priority: .utility) { await understanding.prewarm(locale: .current) }

        var rawCandidates: [EventCandidate] = []
        var understandings: [String: EventUnderstanding] = [:]
        var pageResults: [EventUnderstandingResult] = []
        var texts: [String] = []
        var confidences: [Float] = []

        for (index, page) in pages.enumerated() {
            progressDetail = pages.count > 1 ? "Page \(index + 1) of \(pages.count)" : nil

            // Step 1: On-Device Vision OCR with layout metadata
            stage = .processingOCR
            let ocrResult: OCRResult
            do {
                ocrResult = try await recognizeWithRetry(page)
            } catch DateSnapError.ocr(.noTextRecognized) {
                continue
            } catch {
                if pages.count == 1 {
                    stage = .failed(error.localizedDescription)
                    return
                }
                continue
            }
            texts.append(ocrResult.fullText)
            confidences.append(ocrResult.meanConfidence)

            // Step 2: On-Device NaturalLanguage & Regex Event Extraction
            // Step 2: Deterministic extraction, then (when useful and available) on-device interpretation
            stage = .extractingEvents
            let prepared = await understanding.analyze(ocrResult, locale: .current, anchor: Date(), assetIdentifier: assetIdentifier)
            if prepared.willInterpret { stage = .interpreting }
            let completion = Task { await understanding.complete(prepared) }
            interpretationTask = completion
            let result = await completion.value
            interpretationTask = nil
            pageResults.append(result)
            for event in result.events {
                let candidate = event.best.toExtractedData().toModel()
                candidate.similarityKey = event.best.similarityKey
                candidate.categoryRaw = event.best.category.rawValue
                candidate.rsvpDeadline = event.actions.compactMap(\.deadline).first
                understandings[candidate.id] = event
                rawCandidates.append(candidate)
            }
        }

        let fullText = texts.joined(separator: "\n\n")
        rawOcrText = fullText
        ocrConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

        // Step 3: Multi-field deduplication & SwiftData persistence
        var validCandidates: [EventCandidate] = []
        var alreadySavedCount = 0

        if let context = modelContext {
            var newCandidates: [EventCandidate] = []
            do {
                for candidate in rawCandidates {
                    let key = candidate.dedupeKey
                    let existing: EventCandidate?
                    if key.isEmpty {
                        existing = nil
                    } else {
                        let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.dedupeKey == key })
                        existing = try context.fetch(descriptor).first
                    }

                    if let existing {
                        if existing.savedEvent == nil {
                            // Same flyer scanned again before it was saved: resume reviewing the stored candidate.
                            if !validCandidates.contains(where: { $0.id == existing.id }) {
                                validCandidates.append(existing)
                                understandings[existing.id] = understandings[candidate.id]
                            }
                        } else {
                            alreadySavedCount += 1
                        }
                    } else if !newCandidates.contains(where: { $0.dedupeKey == key && !key.isEmpty }) {
                        newCandidates.append(candidate)
                    }
                }
            } catch {
                stage = .failed("Could not check for an existing event: \(error.localizedDescription)")
                return
            }

            if !newCandidates.isEmpty {
                let scannedAsset = ScannedAsset(
                    assetIdentifier: assetIdentifier,
                    rawOcrText: fullText,
                    ocrConfidence: ocrConfidence,
                    isProcessed: true,
                    candidateCount: newCandidates.count
                )
                context.insert(scannedAsset)
                var newInterpretationRecords: [InterpretationRecord] = []
                for candidate in newCandidates {
                    context.insert(candidate)
                    candidate.scannedAsset = scannedAsset
                    if let understanding = understandings[candidate.id],
                       let result = pageResults.first(where: { $0.events.contains { $0.best.id == understanding.best.id } }),
                       let record = InterpretationRecord.make(for: understanding, in: result) {
                        context.insert(record)
                        newInterpretationRecords.append(record)
                        candidate.interpretation = record
                    }
                }
                do {
                    try context.save()
                } catch {
                    for record in newInterpretationRecords { context.delete(record) }
                    for candidate in newCandidates { context.delete(candidate) }
                    context.delete(scannedAsset)
                    stage = .failed("Could not save the scan: \(error.localizedDescription)")
                    return
                }
            }
            validCandidates += newCandidates
        } else {
            validCandidates = rawCandidates
        }

        self.extractedCandidates = validCandidates
        self.understandingByCandidateID = understandings.filter { id, _ in validCandidates.contains { $0.id == id } }
        self.lastResult = Self.combine(pageResults)

        if !validCandidates.isEmpty {
            stage = .complete(candidates: validCandidates)
        } else if alreadySavedCount > 0 {
            stage = .alreadySaved(count: alreadySavedCount)
        } else {
            stage = .noDatesFound(rawText: fullText)
        }
    }

    /// Runs Vision OCR; if the text is hard to read, retries once on a contrast-enhanced grayscale copy
    /// and keeps whichever pass is more legible.
    private func recognizeWithRetry(_ page: UIImage) async throws -> OCRResult {
        let first: OCRResult
        do {
            first = try await ocrService.recognizeLines(in: page, confidenceFloor: 0.35)
        } catch DateSnapError.ocr(.noTextRecognized) {
            guard let enhanced = ScanImageEnhancer.enhanced(page) else { throw DateSnapError.ocr(.noTextRecognized) }
            return try await ocrService.recognizeLines(in: enhanced, confidenceFloor: 0.35)
        }
        let quality = RuleBasedEventAnalyzer.qualityReport(for: first, anchor: Date())
        guard !quality.isLegible, let enhanced = ScanImageEnhancer.enhanced(page),
              let retry = try? await ocrService.recognizeLines(in: enhanced, confidenceFloor: 0.35) else {
            return first
        }
        let retryQuality = RuleBasedEventAnalyzer.qualityReport(for: retry, anchor: Date())
        let better = retryQuality.meanConfidence > quality.meanConfidence
            || (retryQuality.isScanWorthy && !quality.isScanWorthy)
        return better ? retry : first
    }

    /// Stops a slow on-device interpretation; the scan continues with the rules-based result.
    public func skipInterpretation() {
        interpretationTask?.cancel()
    }

    /// Merges per-page results of a multi-page document into one scan result.
    private static func combine(_ results: [EventUnderstandingResult]) -> EventUnderstandingResult? {
        guard let first = results.first else { return nil }
        guard results.count > 1 else { return first }
        var combined = first
        combined.events = results.flatMap(\.events)
        combined.route = results.contains { $0.route == .onDeviceModel } ? .onDeviceModel : .rulesOnly
        combined.rejectedFieldCount = results.reduce(0) { $0 + $1.rejectedFieldCount }
        combined.quality.isScanWorthy = results.contains { $0.quality.isScanWorthy }
        return combined
    }

    public func reset() {
        stage = .idle
        rawOcrText = ""
        ocrConfidence = 0.0
        extractedCandidates = []
        currentProcessingImage = nil
        isProcessing = false
        progressDetail = nil
        understandingByCandidateID = [:]
        lastResult = nil
    }
}
