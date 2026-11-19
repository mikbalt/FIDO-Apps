/// Renders the human-readable text log. The format is fixed by golden files in the tests.
///
/// Events are written in trace order. v1 traces have only exchanges, so they render exactly as in v1;
/// v2 traces add command, host-step, status and warning lines, and the timeline at the bottom.
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
            switch event {
            case let .exchange(exchange):
                let rx = exchange.rx.isEmpty && !exchange.isRedacted
                    ? "-"
                    : exchange.rxDisplay(hideSensitive: redactSensitive)
                lines.append("\(twoDigits(exchange.index)) \(exchange.label)")
                lines.append("TX \(exchange.txDisplay(hideSensitive: redactSensitive))")
                lines.append("RX \(rx) | SW \(exchange.sw.hex)")
                lines.append("RTT \(TimingFormat.milliseconds(exchange.rtt))")
            case let .command(command):
                var parts = ["CMD \(command.commandIndex) \(command.label)"]
                if let ctapCommand = command.ctapCommand {
                    parts.append("CTAP \(Hex.byte(ctapCommand)) status \(command.ctapStatus.map(Hex.byte) ?? "-")")
                }
                parts.append("SW \(command.sw.hex)")
                parts.append(count(command.exchanges.count, "exchange"))
                parts.append(TimingFormat.milliseconds(command.duration))
                lines.append(parts.joined(separator: " | "))
            case let .hostStep(step):
                lines.append("HOST \(step.label) \(TimingFormat.milliseconds(step.duration))")
            case let .status(_, value):
                lines.append("STATUS \(value.traceValue)")
            case let .warning(warning):
                lines.append("WARN \(warning.code.rawValue): \(warning.message)")
            case .scenarioStarted, .sessionStarted, .cardDetected, .sessionEnded, .scenarioEnded:
                break
            }
        }

        let metrics = TraceMetrics(trace: trace)
        lines.append([
            "Session total \(format(metrics.sessionTotal))",
            "Card wait \(format(metrics.cardWait))",
            "APDU total \(TimingFormat.milliseconds(metrics.apduTotal))",
            "Host \(format(metrics.hostOverhead))",
            count(metrics.exchangeCount, "exchange"),
        ].joined(separator: " | "))

        if trace.scenario != nil {
            lines.append(
                "Scenario total \(format(metrics.scenarioTotal)) = Pre-session \(format(metrics.preSession))"
                    + " + Card wait \(format(metrics.cardWait)) + Card phase \(format(metrics.cardPhase))"
                    + " + Post-session \(format(metrics.postSession))"
            )
            lines.append(
                "Card phase \(format(metrics.cardPhase)) = APDU total \(TimingFormat.milliseconds(metrics.apduTotal))"
                    + " + In-session host \(format(metrics.inSessionHost))"
            )
            if !metrics.commandTotals.isEmpty {
                lines.append("Commands: " + totals(metrics.commandTotals))
            }
            if !metrics.hostStepTotals.isEmpty {
                lines.append("Host steps: " + totals(metrics.hostStepTotals))
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func totals(_ totals: [LabelTotal]) -> String {
        totals.map { "\($0.label) \(TimingFormat.milliseconds($0.total)) (\($0.count))" }.joined(separator: ", ")
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value) \(noun)\(value == 1 ? "" : "s")"
    }

    private static func format(_ nanoseconds: Int64?) -> String {
        nanoseconds.map(TimingFormat.milliseconds) ?? "-"
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
