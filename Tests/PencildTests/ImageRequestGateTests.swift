import Photos
import Testing
import UIKit
@testable import Pencild

/// Covers the resume-once and cancellation rules behind `PhotoLibraryService.fetchImage`
/// (offline audit fix 4) without a real photo library.
@Suite("Image request gate")
struct ImageRequestGateTests {
    private let image = UIImage()

    @Test("Only the first outcome resumes: a degraded image wins over the later final callback")
    func resumesOnce() async throws {
        let gate = ImageRequestGate()
        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, any Error>) in
            gate.install(continuation)
            gate.finish(.success(image))
            gate.finish(.failure(PencildError.photoLibrary(.imageConversionFailed)))
        }
        #expect(result === image)
    }

    @Test("Cancelling returns the Photos request ID and throws CancellationError")
    func cancelReturnsRequestID() async {
        let gate = ImageRequestGate()
        let cancelled = RequestIDBox()
        await #expect(throws: CancellationError.self) {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, any Error>) in
                gate.install(continuation)
                gate.setRequestID(42)
                cancelled.id = gate.cancel()
            }
        }
        #expect(cancelled.id == 42)
    }

    @Test("Cancelling before the continuation exists still throws instead of hanging")
    func cancelBeforeInstall() async {
        let gate = ImageRequestGate()
        #expect(gate.cancel() == nil)
        await #expect(throws: CancellationError.self) {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, any Error>) in
                gate.install(continuation)
            }
        }
    }

    @Test("A late image after cancellation is dropped")
    func lateImageAfterCancelIsDropped() async {
        let gate = ImageRequestGate()
        await #expect(throws: CancellationError.self) {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, any Error>) in
                gate.install(continuation)
                _ = gate.cancel()
                gate.finish(.success(image))
            }
        }
    }
}

private final class RequestIDBox: @unchecked Sendable {
    var id: PHImageRequestID?
}
