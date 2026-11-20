/// Builds a `Trace` from a `CardConnection` and the `RawExchange`s a transport reports.
///
/// An actor, so a channel, a UI observer and a cancellation path can all touch it safely.
public actor TraceRecorder {
    private let metadata: TraceMetadata
    private let connection: CardConnection
    private var events: [TraceEvent]
    private var exchangeCount = 0
    private var commandCount = 0
    private var lastEventTime: Int64

    public init(metadata: TraceMetadata, connection: CardConnection) {
        self.metadata = metadata
        self.connection = connection
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
            card: CardInfo(label: metadata.cardLabel, initialSelectedAID: connection.initialSelectedAID),
            options: metadata.options,
            events: events
        )
    }

    private func offset(of instant: ContinuousClock.Instant) -> Int64 {
        (instant - connection.sessionStartedAt).wholeNanoseconds
    }
}
