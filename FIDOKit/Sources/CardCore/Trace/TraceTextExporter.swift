/// Renders the human-readable text log. The format is fixed by a golden file in the tests.
public enum TraceTextExporter {
    /// - Parameter redactSensitive: Render sensitive exchanges as `<redacted N bytes>`.
    public static func text(for trace: Trace, redactSensitive: Bool = true) -> String {
        var lines: [String] = []
        lines.append(
            "FIDOSims trace \(trace.id.uuidString) | \(trace.transport.rawValue) | "
                + "\(trace.device.model) \(trace.device.os) | \(trace.card.label)"
        )

        for exchange in trace.exchanges {
            let rx = exchange.rx.isEmpty && !exchange.isRedacted
                ? "-"
                : exchange.rxDisplay(hideSensitive: redactSensitive)
            lines.append("\(twoDigits(exchange.index)) \(exchange.label)")
            lines.append("TX \(exchange.txDisplay(hideSensitive: redactSensitive))")
            lines.append("RX \(rx) | SW \(exchange.sw.hex)")
            lines.append("RTT \(TimingFormat.milliseconds(exchange.rtt))")
        }

        let metrics = TraceMetrics(trace: trace)
        let noun = metrics.exchangeCount == 1 ? "exchange" : "exchanges"
        lines.append([
            "Session total \(format(metrics.sessionTotal))",
            "Card wait \(format(metrics.cardWait))",
            "APDU total \(TimingFormat.milliseconds(metrics.apduTotal))",
            "Host \(format(metrics.hostOverhead))",
            "\(metrics.exchangeCount) \(noun)",
        ].joined(separator: " | "))

        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ nanoseconds: Int64?) -> String {
        nanoseconds.map(TimingFormat.milliseconds) ?? "-"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
