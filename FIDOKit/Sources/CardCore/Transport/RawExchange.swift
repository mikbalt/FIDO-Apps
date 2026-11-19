import Foundation

public struct RawExchange: Sendable {
    public let command: Data                      // exact bytes sent
    public let response: ResponseAPDU
    public let startedAt: ContinuousClock.Instant // taken immediately before the I/O call
    public let endedAt: ContinuousClock.Instant   // taken immediately after it returns

    public init(
        command: Data,
        response: ResponseAPDU,
        startedAt: ContinuousClock.Instant,
        endedAt: ContinuousClock.Instant
    ) {
        self.command = command
        self.response = response
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}
