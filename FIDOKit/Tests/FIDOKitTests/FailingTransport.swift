import FIDOKit
import Foundation

/// Fails with a fixed `CardError`: on the first `transmit`, or already in `open`.
final class FailingTransport: CardTransport {
    let kind: TransportKind = .mock
    let error: CardError
    let failsOpen: Bool

    init(error: CardError, failsOpen: Bool = false) {
        self.error = error
        self.failsOpen = failsOpen
    }

    func open(prompt: String) async throws -> CardConnection {
        if failsOpen { throw error }
        let now = ContinuousClock.now
        return CardConnection(sessionStartedAt: now, cardDetectedAt: now, initialSelectedAID: nil)
    }

    func transmit(_ command: Data) async throws -> RawExchange {
        throw error
    }

    func close(errorMessage: String?) async {}
}
