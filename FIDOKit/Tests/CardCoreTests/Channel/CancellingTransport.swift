import CardCore
import Foundation

/// Wraps a transport and cancels the calling task after a number of transmits.
actor CancellingTransport: CardTransport {
    nonisolated let kind: TransportKind = .mock
    private let inner: MockTransport
    private let cancelAfter: Int
    private var count = 0

    init(inner: MockTransport, cancelAfter: Int) {
        self.inner = inner
        self.cancelAfter = cancelAfter
    }

    func open(prompt: String) async throws -> CardConnection {
        try await inner.open(prompt: prompt)
    }

    func transmit(_ command: Data) async throws -> RawExchange {
        let exchange = try await inner.transmit(command)
        count += 1
        if count == cancelAfter {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        return exchange
    }

    func close(errorMessage: String?) async {
        await inner.close(errorMessage: errorMessage)
    }
}
