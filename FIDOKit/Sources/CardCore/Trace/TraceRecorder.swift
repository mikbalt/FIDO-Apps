import Foundation

/// Builds a `Trace` from a `CardConnection` and the `RawExchange`s a transport reports.
///
/// An actor, so a channel, a UI observer and a cancellation path can all touch it safely. Recording only
/// appends to memory, so it does not distort the timings it records.
public actor TraceRecorder {
    private let metadata: TraceMetadata
    private let connection: CardConnection
    private var card: CardInfo
    private var outcome: TraceOutcome?
    private var events: [TraceEvent]
    private var exchangeCount = 0
    private var commandCount = 0
    private var lastEventTime: Int64

    public init(metadata: TraceMetadata, connection: CardConnection) {
        self.metadata = metadata
        self.connection = connection
        self.card = CardInfo(label: metadata.cardLabel, initialSelectedAID: connection.initialSelectedAID)
        let detected = (connection.cardDetectedAt - connection.sessionStartedAt).wholeNanoseconds
        self.events = [.sessionStarted(t: 0), .cardDetected(t: detected)]
        self.lastEventTime = detected
    }

    /// Reserves the next 1-based logical command index.
    public func nextCommandIndex() -> Int {
        commandCount += 1
        return commandCount
    }

    /// Appends one physical exchange.
    public func record(_ exchange: RawExchange, commandIndex: Int, label: String, sensitive: Bool) {
        exchangeCount += 1
        let event = ExchangeEvent(
            index: exchangeCount,
            commandIndex: commandIndex,
            label: label,
            tx: exchange.command,
            rx: exchange.response.data,
            sw: exchange.response.sw,
            tStart: offset(of: exchange.startedAt),
            tEnd: offset(of: exchange.endedAt),
            sensitive: sensitive
        )
        events.append(.exchange(event))
        lastEventTime = max(lastEventTime, event.tEnd)
    }

    /// Sets `ctapStatus` on the last exchange: the one that completed a CTAP command.
    public func markCTAPStatus(_ status: UInt8) {
        guard let index = events.lastIndex(where: { if case .exchange = $0 { true } else { false } }),
              case var .exchange(exchange) = events[index] else { return }
        exchange.ctapStatus = status
        events[index] = .exchange(exchange)
    }

    public func recordWarning(_ code: TraceWarningCode, _ message: String, at instant: ContinuousClock.Instant = .now) {
        events.append(.warning(WarningEvent(t: max(offset(of: instant), 0), code: code, message: message)))
    }

    /// Fills the card metadata learned from GetInfo.
    public func setCardDetails(aaguid: UUID?, versions: [String]?, firmwareVersion: UInt64?) {
        card.aaguid = aaguid
        card.versions = versions
        card.firmwareVersion = firmwareVersion
    }

    /// Sets the scenario outcome. The first call wins.
    public func finish(_ outcome: TraceOutcome) {
        guard self.outcome == nil else { return }
        self.outcome = outcome
    }

    /// Appends `sessionEnded`. Ignored if the session already ended.
    ///
    /// The time is clamped so it never precedes the last exchange: a mock transport reports
    /// recorded times that can be ahead of the real clock.
    public func end(reason: SessionEndReason, at instant: ContinuousClock.Instant = .now) {
        guard endReason == nil else { return }
        events.append(.sessionEnded(t: max(offset(of: instant), lastEventTime), reason: reason))
    }

    public var endReason: SessionEndReason? {
        for case let .sessionEnded(_, reason) in events {
            return reason
        }
        return nil
    }

    public var trace: Trace {
        Trace(
            id: metadata.id,
            createdAt: metadata.createdAt,
            app: metadata.app,
            transport: metadata.transport,
            device: metadata.device,
            scenario: metadata.scenario,
            outcome: outcome,
            card: card,
            options: metadata.options,
            events: events
        )
    }

    private func offset(of instant: ContinuousClock.Instant) -> Int64 {
        (instant - connection.sessionStartedAt).wholeNanoseconds
    }
}
