import SwiftUI
import UIKit
import VisionKit

/// Presents Apple's local document scanner and returns captured page images without saving them automatically.
struct DocumentCameraScanner: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onError: (Error) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel, onError: onError)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let onScan: ([UIImage]) -> Void
        private let onCancel: () -> Void
        private let onError: (Error) -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void, onError: @escaping (Error) -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
            self.onError = onError
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else {
                onCancel()
                return
            }
            onScan((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onError(error)
        }
    }
}
