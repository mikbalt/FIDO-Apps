/// Timing metrics for a trace, in nanoseconds. Definitions are provisional; see `docs/trace-format.md`.
public struct TraceMetrics: Sendable, Equatable {
    /// `cardDetected − sessionStarted`. `nil` if the card was never detected.
    public var cardWait: Int64?
    /// Σ (`tEnd − tStart`) over all exchanges.
    public var apduTotal: Int64
    /// `tEnd` of the last exchange − `sessionStarted`. `nil` without exchanges.
    public var sessionTotal: Int64?
    /// `sessionTotal − cardWait − apduTotal`: app processing plus stack time between exchanges.
    public var hostOverhead: Int64?
    public var exchangeCount: Int
    /// Per logical command, in command order.
    public var commands: [CommandMetrics]

    public init(trace: Trace) {
        let start = trace.sessionStartedTime ?? 0
        let exchanges = trace.exchanges

        cardWait = trace.cardDetectedTime.map { $0 - start }
        apduTotal = exchanges.reduce(0) { $0 + $1.rtt }
        sessionTotal = exchanges.last.map { $0.tEnd - start }
        if let sessionTotal, let cardWait {
            hostOverhead = sessionTotal - cardWait - apduTotal
        } else {
            hostOverhead = nil
        }
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
    }
}
