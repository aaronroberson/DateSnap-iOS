import Foundation
import UIKit
import Vision

// MARK: - Structured OCR Models

/// A single recognized line of text with Vision-normalized bounding box and derived layout metrics.
public struct OCRLine: Sendable, Identifiable {
    public var id: UUID
    public var text: String
    public var confidence: Float
    /// Vision-normalized bounding box [0, 1] with origin at lower-left.
    public var boundingBox: CGRect
    /// Ratio of normalized height to character count, used as a typography size rank proxy.
    public var fontSizeProxy: CGFloat

    public var normalizedWidth: CGFloat { boundingBox.width }
    public var normalizedY: CGFloat { boundingBox.origin.y }
    public var normalizedMaxY: CGFloat { boundingBox.maxY }

    public init(
        id: UUID = UUID(),
        text: String,
        confidence: Float,
        boundingBox: CGRect
    ) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.fontSizeProxy = boundingBox.height / CGFloat(max(1, text.count))
    }
}

/// The structured result of an on-device OCR scan, carrying lines ordered for reading and aggregate metrics.
public struct OCRResult: Sendable {
    public var fullText: String
    public var lines: [OCRLine]
    public var meanConfidence: Float

    public init(fullText: String, lines: [OCRLine], meanConfidence: Float) {
        self.fullText = fullText
        self.lines = lines
        self.meanConfidence = meanConfidence
    }
}

// MARK: - OCR Service Protocol

public protocol OCRServiceProtocol: Sendable {
    /// Baseline text recognition returning aggregated plain text and mean confidence.
    func recognizeText(in image: UIImage) async throws -> (fullText: String, confidence: Float)

    /// Structured text recognition returning ordered lines with layout geometry and font size proxies.
    func recognizeLines(in image: UIImage, confidenceFloor: Float) async throws -> OCRResult
}

extension OCRServiceProtocol {
    public func recognizeLines(in image: UIImage) async throws -> OCRResult {
        try await recognizeLines(in: image, confidenceFloor: 0.35)
    }
}

// MARK: - Production OCR Service

public final class OCRService: OCRServiceProtocol {
    public init() {}

    public func recognizeText(in image: UIImage) async throws -> (fullText: String, confidence: Float) {
        let result = try await recognizeLines(in: image, confidenceFloor: 0.0)
        return (fullText: result.fullText, confidence: result.meanConfidence)
    }

    public func recognizeLines(in image: UIImage, confidenceFloor: Float = 0.35) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw DateSnapError.ocr(.imageProcessingFailed)
        }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        // Process OCR on background thread off the main actor
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

            do {
                try handler.perform([request])
            } catch {
                throw DateSnapError.ocr(.visionRequestFailed(error.localizedDescription))
            }

            guard let observations = request.results, !observations.isEmpty else {
                throw DateSnapError.ocr(.noTextRecognized)
            }

            var detectedLines: [OCRLine] = []
            var totalConfidence: Float = 0.0

            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        let line = OCRLine(
                            text: text,
                            confidence: candidate.confidence,
                            boundingBox: observation.boundingBox
                        )
                        detectedLines.append(line)
                        totalConfidence += candidate.confidence
                    }
                }
            }

            guard !detectedLines.isEmpty else {
                throw DateSnapError.ocr(.noTextRecognized)
            }

            // In Vision coordinates, origin is lower-left (0,0) and top is (1,1).
            // Sort top-to-bottom: higher maxY appears higher on the physical flyer/screenshot.
            detectedLines.sort { $0.boundingBox.maxY > $1.boundingBox.maxY }

            let fullText = detectedLines.map { $0.text }.joined(separator: "\n")
            let meanConfidence = totalConfidence / Float(detectedLines.count)

            // Guard against unreadable or heavily blurred screenshots
            if meanConfidence < confidenceFloor {
                throw DateSnapError.ocr(.insufficientConfidence(meanConfidence))
            }

            return OCRResult(fullText: fullText, lines: detectedLines, meanConfidence: meanConfidence)
        }.value
    }
}

// MARK: - CGImagePropertyOrientation Helper

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
