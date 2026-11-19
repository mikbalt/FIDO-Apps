import Foundation

public struct CardConnection: Sendable {
    public let sessionStartedAt: ContinuousClock.Instant
    public let cardDetectedAt: ContinuousClock.Instant
    public let initialSelectedAID: Data?          // what the OS already selected during discovery

    public init(
        sessionStartedAt: ContinuousClock.Instant,
        cardDetectedAt: ContinuousClock.Instant,
        initialSelectedAID: Data?
    ) {
        self.sessionStartedAt = sessionStartedAt
        self.cardDetectedAt = cardDetectedAt
        self.initialSelectedAID = initialSelectedAID
    }
}
