/// Timing metrics for a trace, in nanoseconds. See "Timeline" in `docs/trace-format.md`.
///
/// ```
/// scenarioTotal = preSession + cardWait + cardPhase + postSession
/// sessionTotal  = cardWait + cardPhase
/// cardPhase     = apduTotal + inSessionHost
/// ```
///
/// A segment is `nil` when an event it needs is missing: v1 traces have no scenario bounds, and a scenario
/// that ended before a card connected has no session.
public struct TraceMetrics: Sendable, Equatable {
    /// `sessionStarted − scenarioStarted`: app work before the NFC sheet opens.
    public var preSession: Int64?
    /// `cardDetected − sessionStarted`: sheet, user tap and CoreNFC's implicit SELECT.
    public var cardWait: Int64?
    /// `lastExchangeEnd − cardDetected`.
    public var cardPhase: Int64?
    /// Σ (`tEnd − tStart`) over all exchanges.
    public var apduTotal: Int64
    /// `cardPhase − apduTotal`: app processing plus stack time between exchanges.
    public var inSessionHost: Int64?
    /// `scenarioEnded − lastExchangeEnd`: session close, RP verification, storage.
    public var postSession: Int64?
    /// `scenarioEnded − scenarioStarted`.
    public var scenarioTotal: Int64?
    /// `lastExchangeEnd − sessionStarted` (= `cardWait + cardPhase`; the v1 metric).
    public var sessionTotal: Int64?
    public var exchangeCount: Int
    /// Per logical command, from the exchanges, in command order.
    public var commands: [CommandMetrics]
    /// Per label, from `command` events (v2): their durations include time between exchanges.
    public var commandTotals: [LabelTotal]
    /// Per label, from `hostStep` events (v2).
    public var hostStepTotals: [LabelTotal]

    /// The v1 name of `inSessionHost`.
    public var hostOverhead: Int64? { inSessionHost }

    public init(trace: Trace) {
        let exchanges = trace.exchanges
        let scenarioStarted = trace.scenarioStartedTime
        let sessionStarted = trace.sessionStartedTime
        let cardDetected = trace.cardDetectedTime
        let lastExchangeEnd = exchanges.last?.tEnd
        let scenarioEnded = trace.scenarioEndedTime

        func difference(_ end: Int64?, _ start: Int64?) -> Int64? {
            guard let end, let start else { return nil }
            return end - start
        }

        // `sessionStarted` is the reference (0) of a v1 trace, so a v1 trace without the event still works.
        preSession = difference(sessionStarted, scenarioStarted)
        cardWait = difference(cardDetected, sessionStarted ?? 0)
        cardPhase = difference(lastExchangeEnd, cardDetected)
        let apduTotal = exchanges.reduce(0) { $0 + $1.rtt }
        self.apduTotal = apduTotal
        inSessionHost = cardPhase.map { $0 - apduTotal }
        postSession = difference(scenarioEnded, lastExchangeEnd)
        scenarioTotal = difference(scenarioEnded, scenarioStarted)
        sessionTotal = difference(lastExchangeEnd, sessionStarted ?? 0)
        exchangeCount = exchanges.count

        var commands: [CommandMetrics] = []
        for exchange in exchanges {
            if let last = commands.indices.last, commands[last].commandIndex == exchange.commandIndex {
                commands[last].rtt += exchange.rtt
                commands[last].exchangeCount += 1
            } else {
                commands.append(CommandMetrics(
                    commandIndex: exchange.commandIndex, label: exchange.label,
                    rtt: exchange.rtt, exchangeCount: 1
                ))
            }
        }
        self.commands = commands
        commandTotals = LabelTotal.totals(trace.commands.map { ($0.label, $0.duration) })
        hostStepTotals = LabelTotal.totals(trace.hostSteps.map { ($0.label, $0.duration) })
    }
}
