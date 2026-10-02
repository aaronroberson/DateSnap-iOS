import Foundation

public struct MutationFailure: Error, Equatable, LocalizedError {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public init(_ error: Error) {
        self.message = error.localizedDescription
    }

    public var errorDescription: String? { message }
}

public enum MutationResult: Equatable {
    case success
    case partial([String])
    case failure(MutationFailure)

    static func perform(_ operation: () throws -> Void) -> MutationResult {
        do {
            try operation()
            return .success
        } catch {
            return .failure(MutationFailure(error))
        }
    }
}
