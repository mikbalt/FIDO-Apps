import FIDOKit
import Foundation

/// Connects, then fails the first `transmit` with a fixed `CardError`.
final class FailingTransport: CardTransport {
    let kind: TransportKind = .mock
    let error: CardError

    init(error: CardError) {
        self.error = error
    }

    func open(prompt: String) async throws -> CardConnection {
        let now = ContinuousClock.now
        return CardConnection(sessionStartedAt: now, cardDetectedAt: now, initialSelectedAID: nil)
    }

    func transmit(_ command: Data) async throws -> RawExchange {
        throw error
    }

    func close(errorMessage: String?) async {}
}
