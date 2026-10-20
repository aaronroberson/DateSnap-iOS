import Foundation

// MARK: - Deadline

/// Thrown by `withDeadline` when the operation did not finish in time.
struct DeadlineExceeded: Error, Sendable {}

/// Runs `operation` and returns its result, or throws `DeadlineExceeded` once `timeout` elapses.
///
/// Unlike racing two children in a task group, this returns at the deadline even when the
/// operation ignores cancellation (a task group always waits for every child before it returns).
/// That matters for StoreKit streams, which can stall offline. On timeout the operation is
/// cancelled and left to wind down in the background; its late result is discarded.
func withDeadline<T: Sendable>(
    _ timeout: Duration,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let state = DeadlineState<T>()
    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, any Error>) in
            state.install(continuation)
            state.track(Task {
                do {
                    state.finish(.success(try await operation()))
                } catch {
                    state.finish(.failure(error))
                }
            })
            state.track(Task {
                try? await Task.sleep(for: timeout)
                state.finish(.failure(DeadlineExceeded()))
            })
        }
    } onCancel: {
        state.finish(.failure(CancellationError()))
    }
}

/// Resume-once bookkeeping for `withDeadline`. Whichever of the work, the timer or caller
/// cancellation finishes first wins; the others are cancelled and their results dropped.
private final class DeadlineState<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    private var outcome: Result<T, any Error>?
    private var tasks: [Task<Void, Never>] = []

    func install(_ continuation: CheckedContinuation<T, any Error>) {
        lock.lock()
        if let outcome {
            // Cancelled before the continuation existed.
            lock.unlock()
            continuation.resume(with: outcome)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func track(_ task: Task<Void, Never>) {
        lock.lock()
        let alreadyFinished = outcome != nil
        if !alreadyFinished { tasks.append(task) }
        lock.unlock()
        if alreadyFinished { task.cancel() }
    }

    func finish(_ result: Result<T, any Error>) {
        lock.lock()
        guard outcome == nil else {
            lock.unlock()
            return
        }
        outcome = result
        let continuation = self.continuation
        self.continuation = nil
        let tasks = self.tasks
        self.tasks = []
        lock.unlock()
        continuation?.resume(with: result)
        tasks.forEach { $0.cancel() }
    }
}
