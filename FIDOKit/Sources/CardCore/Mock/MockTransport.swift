import Foundation

/// Replays a recorded trace: for each expected `tx`, in order, it answers with the recorded `rx`/`sw`.
///
/// Reported timestamps are the recorded ones, offset from the moment `open` is called, so metrics of a
/// replay equal those of the fixture. Nothing sleeps unless `realtime` is true, in which case each call
/// waits until its recorded end time.
public actor MockTransport: CardTransport {
    public nonisolated let kind: TransportKind = .mock

    private let script: [ExchangeEvent]
    private let cardWait: Int64
    private let initialSelectedAID: Data?
    private let realtime: Bool
    private let clock = ContinuousClock()
    private var sessionStartedAt: ContinuousClock.Instant?
    private var position = 0

    public init(trace: Trace, realtime: Bool = false) throws {
        let exchanges = trace.exchanges
        if let redacted = exchanges.first(where: \.isRedacted) {
            throw MockTransportError.redactedFixture(index: redacted.index)
        }
        let start = trace.sessionStartedTime ?? 0
        self.script = exchanges.map { exchange in
            var shifted = exchange
            shifted.tStart -= start
            shifted.tEnd -= start
            return shifted
        }
        self.cardWait = (trace.cardDetectedTime ?? start) - start
        self.initialSelectedAID = trace.card.initialSelectedAID
        self.realtime = realtime
    }

    public init(fixtureURL: URL, realtime: Bool = false) throws {
        try self.init(trace: Trace(jsonData: Data(contentsOf: fixtureURL)), realtime: realtime)
    }

    /// Scripted exchanges not yet consumed.
    public var remainingExchanges: Int { script.count - position }

    public func open(prompt: String) async throws -> CardConnection {
        let start = clock.now
        sessionStartedAt = start
        position = 0
        let detected = start + .nanoseconds(cardWait)
        if realtime {
            try await clock.sleep(until: detected)
        }
        return CardConnection(
            sessionStartedAt: start,
            cardDetectedAt: detected,
            initialSelectedAID: initialSelectedAID
        )
    }

    public func transmit(_ command: Data) async throws -> RawExchange {
        guard let start = sessionStartedAt else { throw MockTransportError.notOpen }
        guard position < script.count else { throw MockTransportError.scriptExhausted(actual: command) }

        let expected = script[position]
        guard command == expected.tx else {
            throw MockTransportError.unexpectedCommand(
                index: expected.index, label: expected.label, expected: expected.tx, actual: command
            )
        }
        position += 1

        let ended = start + .nanoseconds(expected.tEnd)
        if realtime {
            try await clock.sleep(until: ended)
        }
        return RawExchange(
            command: command,
            response: ResponseAPDU(data: expected.rx, sw: expected.sw),
            startedAt: start + .nanoseconds(expected.tStart),
            endedAt: ended
        )
    }

    public func close(errorMessage: String?) async {
        sessionStartedAt = nil
    }
}
