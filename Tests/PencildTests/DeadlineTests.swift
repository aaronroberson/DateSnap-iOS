import Foundation
import Testing
@testable import Pencild

@Suite("withDeadline")
struct DeadlineTests {
    @Test("Returns the operation's value when it finishes in time")
    func returnsValue() async throws {
        let value = try await withDeadline(.seconds(2)) { 42 }
        #expect(value == 42)
    }

    @Test("Rethrows the operation's own error")
    func rethrowsOperationError() async {
        struct Boom: Error {}
        await #expect(throws: Boom.self) {
            _ = try await withDeadline(.seconds(2)) { () async throws -> Int in throw Boom() }
        }
    }

    @Test("Times out on time even when the operation ignores cancellation")
    func timesOutOnStalledOperation() async {
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: DeadlineExceeded.self) {
            _ = try await withDeadline(.milliseconds(200)) { () async -> Int in
                // Simulates a StoreKit stream that never checks for cancellation.
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) { continuation.resume() }
                }
                return 1
            }
        }
        #expect(clock.now - start < .seconds(1))
    }
}
