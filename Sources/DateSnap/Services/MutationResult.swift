import Foundation

public struct MutationFailure: Error, Equatable, LocalizedError {
    let message: String

    init(_ error: Error) {
        self.message = error.localizedDescription
    }

    init(message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

public enum MutationResult: Equatable {
    case success
    case partial([String])
    case failure(MutationFailure)

    var completed: Bool {
        switch self {
        case .success, .partial: true
        case .failure: false
        }
    }

    var issueMessage: String? {
        switch self {
        case .success:
            nil
        case .partial(let issues):
            issues.joined(separator: "; ")
        case .failure(let error):
            error.localizedDescription
        }
    }

    static func perform(_ operation: () throws -> Void) -> MutationResult {
        do {
            try operation()
            return .success
        } catch {
            return .failure(MutationFailure(error))
        }
    }
}
