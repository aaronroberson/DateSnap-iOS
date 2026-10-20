import Foundation

/// How soon to ask StoreKit again after a failed or provisional entitlement check. A quick first
/// retry catches a momentary stall; later retries back off to a steady, battery-friendly rate.
public struct EntitlementRetryPolicy: Sendable, Equatable {
    public let delays: [Duration]
    public let steadyDelay: Duration

    public static let standard = EntitlementRetryPolicy(
        delays: [.seconds(2), .seconds(5), .seconds(15), .seconds(60)],
        steadyDelay: .seconds(300)
    )

    public init(delays: [Duration], steadyDelay: Duration) {
        self.delays = delays
        self.steadyDelay = steadyDelay
    }

    /// The wait before the next attempt, given how many attempts have already failed.
    public func delay(afterFailures failures: Int) -> Duration {
        failures < delays.count ? delays[max(0, failures)] : steadyDelay
    }
}
