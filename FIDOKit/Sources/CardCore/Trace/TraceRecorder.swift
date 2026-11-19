import Foundation

/// Builds a `Trace` from a scenario's events: the card connection, `RawExchange`s, commands, host steps,
/// status updates and warnings.
///
/// An actor, so a channel, a UI observer and a cancellation path can all touch it safely. Recording only
/// appends to memory: no I/O, no UI work, so it does not distort the timings it records.
///
/// Times are nanoseconds since `scenarioStarted` (`t = 0`). A mock transport reports recorded times that can
/// be ahead of the real clock, so `sessionEnded` and `scenarioEnded` are clamped to never precede the last
/// exchange or command.
public actor TraceRecorder {
    private let metadata: TraceMetadata
    private let scenario: TraceScenario
    private let scenarioStartedAt: ContinuousClock.Instant
    private var card: CardInfo
    private var outcome: TraceOutcome?
    private var events: [TraceEvent] = [.scenarioStarted(t: 0)]
    private var exchangeCount = 0
    private var commandCount = 0
    private var lastEventTime: Int64 = 0

    /// Starts a scenario: emits `scenarioStarted`. Call before opening the transport.
    public init(metadata: TraceMetadata, scenario: TraceScenario, startedAt: ContinuousClock.Instant = .now) {
        self.metadata = metadata
        self.scenario = scenario
        self.scenarioStartedAt = startedAt
        self.card = CardInfo(label: metadata.cardLabel, initialSelectedAID: nil)
    }

    /// A `raw` scenario that starts with an already open connection, for low-level channel use and tests.
    public init(metadata: TraceMetadata, connection: CardConnection) {
        let detected = (connection.cardDetectedAt - connection.sessionStartedAt).wholeNanoseconds
        self.metadata = metadata
        self.scenario = .raw
        self.scenarioStartedAt = connection.sessionStartedAt
        self.card = CardInfo(label: metadata.cardLabel, initialSelectedAID: connection.initialSelectedAID)
        self.events = [.scenarioStarted(t: 0), .sessionStarted(t: 0), .cardDetected(t: detected)]
        self.lastEventTime = detected
    }

    /// Emits `sessionStarted` and `cardDetected` from the transport's timestamps.
    public func connected(_ connection: CardConnection) {
        let started = offset(of: connection.sessionStartedAt)
        let detected = offset(of: connection.cardDetectedAt)
        events += [.sessionStarted(t: started), .cardDetected(t: detected)]
        lastEventTime = max(lastEventTime, detected)
        card.initialSelectedAID = connection.initialSelectedAID
    }

    /// Reserves the next 1-based logical command index.
    public func nextCommandIndex() -> Int {
        commandCount += 1
        return commandCount
    }

    /// Appends one physical exchange and returns it, with its index and times.
    @discardableResult
    public func record(_ exchange: RawExchange, commandIndex: Int, label: String, sensitive: Bool) -> ExchangeEvent {
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
        return event
    }

    /// Appends a logical command, after its last exchange.
    public func record(_ command: CommandEvent) {
        events.append(.command(command))
        lastEventTime = max(lastEventTime, command.tEnd)
    }

    /// Appends app-side work, measured by the caller.
    public func recordHostStep(_ label: String, start: ContinuousClock.Instant, end: ContinuousClock.Instant) {
        events.append(.hostStep(HostStepEvent(label: label, tStart: offset(of: start), tEnd: offset(of: end))))
    }

    /// Appends an NFCCTAP status update.
    public func recordStatus(_ status: NFCCTAPStatus, at instant: ContinuousClock.Instant) {
        events.append(.status(t: offset(of: instant), value: status))
    }

    public func recordWarning(_ code: TraceWarningCode, _ message: String, at instant: ContinuousClock.Instant = .now) {
        events.append(.warning(WarningEvent(t: offset(of: instant), code: code, message: message)))
    }

    /// Fills the card metadata learned from GetInfo.
    public func setCardDetails(aaguid: UUID?, versions: [String]?, firmwareVersion: UInt64?) {
        card.aaguid = aaguid
        card.versions = versions
        card.firmwareVersion = firmwareVersion
    }

    /// Appends `sessionEnded`. Ignored if the session already ended.
    public func end(reason: SessionEndReason, at instant: ContinuousClock.Instant = .now) {
        guard endReason == nil else { return }
        events.append(.sessionEnded(t: max(offset(of: instant), lastEventTime), reason: reason))
    }

    /// Appends `scenarioEnded` and sets the outcome. Ignored if the scenario already ended.
    public func finish(_ outcome: TraceOutcome, at instant: ContinuousClock.Instant = .now) {
        guard self.outcome == nil else { return }
        self.outcome = outcome
        let sessionEnd = events.reversed().lazy.compactMap { event -> Int64? in
            if case let .sessionEnded(t, _) = event { t } else { nil }
        }.first ?? 0
        events.append(.scenarioEnded(t: max(offset(of: instant), lastEventTime, sessionEnd)))
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
            scenario: scenario,
            outcome: outcome,
            card: card,
            options: metadata.options,
            events: events
        )
    }

    private func offset(of instant: ContinuousClock.Instant) -> Int64 {
        (instant - scenarioStartedAt).wholeNanoseconds
    }
}
