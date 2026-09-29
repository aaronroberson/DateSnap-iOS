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
    private let extractionService: EventExtractionServiceProtocol

    // MARK: - Pipeline State
    public enum ScanStage: Equatable {
        case idle
        case fetchingImage
        case processingOCR
        case extractingEvents
        case complete(candidates: [EventCandidate])
        case noDatesFound(rawText: String)
        /// Every detected event is already saved in History.
        case alreadySaved(count: Int)
        case failed(String)

        public static func == (lhs: ScanStage, rhs: ScanStage) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.fetchingImage, .fetchingImage), (.processingOCR, .processingOCR), (.extractingEvents, .extractingEvents):
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

    public init(services: ServiceContainer) {
        self.photoLibraryService = services.photoLibrary
        self.ocrService = services.ocr
        self.extractionService = services.eventExtraction
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

        var rawCandidates: [EventCandidate] = []
        var texts: [String] = []
        var confidences: [Float] = []

        for (index, page) in pages.enumerated() {
            progressDetail = pages.count > 1 ? "Page \(index + 1) of \(pages.count)" : nil

            // Step 1: On-Device Vision OCR with layout metadata
            stage = .processingOCR
            let ocrResult: OCRResult
            do {
                ocrResult = try await ocrService.recognizeLines(in: page, confidenceFloor: 0.35)
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
            stage = .extractingEvents
            rawCandidates += await extractionService.extractCandidates(from: ocrResult, locale: .current)
        }

        let fullText = texts.joined(separator: "\n\n")
        rawOcrText = fullText
        ocrConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)

        // Step 3: Multi-field deduplication & SwiftData persistence
        var validCandidates: [EventCandidate] = []
        var alreadySavedCount = 0

        if let context = modelContext {
            var newCandidates: [EventCandidate] = []
            for candidate in rawCandidates {
                let key = candidate.dedupeKey
                let existing: EventCandidate? = key.isEmpty ? nil : {
                    let descriptor = FetchDescriptor<EventCandidate>(predicate: #Predicate { $0.dedupeKey == key })
                    return (try? context.fetch(descriptor))?.first
                }()

                if let existing {
                    if existing.savedEvent == nil {
                        // Same flyer scanned again before it was saved: resume reviewing the stored candidate.
                        if !validCandidates.contains(where: { $0.id == existing.id }) {
                            validCandidates.append(existing)
                        }
                    } else {
                        alreadySavedCount += 1
                    }
                } else if !newCandidates.contains(where: { $0.dedupeKey == key && !key.isEmpty }) {
                    newCandidates.append(candidate)
                }
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
                for candidate in newCandidates {
                    context.insert(candidate)
                    candidate.scannedAsset = scannedAsset
                }
                try? context.save()
            }
            validCandidates += newCandidates
        } else {
            validCandidates = rawCandidates
        }

        self.extractedCandidates = validCandidates

        if !validCandidates.isEmpty {
            stage = .complete(candidates: validCandidates)
        } else if alreadySavedCount > 0 {
            stage = .alreadySaved(count: alreadySavedCount)
        } else {
            stage = .noDatesFound(rawText: fullText)
        }
    }

    public func reset() {
        stage = .idle
        rawOcrText = ""
        ocrConfidence = 0.0
        extractedCandidates = []
        currentProcessingImage = nil
        isProcessing = false
        progressDetail = nil
    }
}
