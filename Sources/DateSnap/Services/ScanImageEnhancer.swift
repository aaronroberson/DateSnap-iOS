import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - Scan Image Enhancer
/// Local contrast/grayscale pass used to retry OCR once on low-legibility scans (stylized, low-contrast flyers).
enum ScanImageEnhancer {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func enhanced(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let input = CIImage(cgImage: cgImage)
        let controls = CIFilter.colorControls()
        controls.inputImage = input
        controls.saturation = 0
        controls.contrast = 1.6
        controls.brightness = 0.02
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = controls.outputImage
        sharpen.sharpness = 0.6
        guard let output = sharpen.outputImage,
              let rendered = context.createCGImage(output, from: input.extent) else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}
