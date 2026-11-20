/// Renders the human-readable text log. The format is fixed by golden files in the tests.
///
/// v1 traces render exactly as in v1. v2 adds the scenario and outcome to the header, the CTAP status after
/// the exchange that completed a CTAP command, and one line per warning.
public enum TraceTextExporter {
    /// - Parameter redactSensitive: Render sensitive exchanges as `<redacted N bytes>`.
    public static func text(for trace: Trace, redactSensitive: Bool = true) -> String {
        var header = "FIDOSims trace \(trace.id.uuidString) | \(trace.transport.rawValue) | "
            + "\(trace.device.model) \(trace.device.os) | \(trace.card.label)"
        if let scenario = trace.scenario {
            header += " | \(scenario.rawValue)"
            if let outcome = trace.outcome {
                header += " \(outcome.status.rawValue)"
                if let error = outcome.error {
                    header += " \(error.domain.rawValue) \(error.name)"
                }
            }
        }
        var lines = [header]

        for event in trace.events {
            if case let .warning(warning) = event {
                lines.append("WARN \(warning.code.rawValue): \(warning.message)")
            }
            guard case let .exchange(exchange) = event else { continue }
            let rx = exchange.rx.isEmpty && !exchange.isRedacted
                ? "-"
                : exchange.rxDisplay(hideSensitive: redactSensitive)
            lines.append("\(twoDigits(exchange.index)) \(exchange.label)")
            lines.append("TX \(exchange.txDisplay(hideSensitive: redactSensitive))")
            lines.append("RX \(rx) | SW \(exchange.sw.hex)")
            lines.append("RTT \(TimingFormat.milliseconds(exchange.rtt))")
            if let status = exchange.ctapStatus {
                lines.append("CTAP status \(Hex.byte(status))")
            }
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
