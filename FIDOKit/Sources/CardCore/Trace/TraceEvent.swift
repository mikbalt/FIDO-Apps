/// An ordered event in a trace. Times are monotonic nanoseconds since `scenarioStarted` (v2) or
/// `sessionStarted` (v1).
public enum TraceEvent: Sendable, Equatable {
    /// v2. Always `t = 0`: the reference time.
    case scenarioStarted(t: Int64)
    case sessionStarted(t: Int64)
    case cardDetected(t: Int64)
    case exchange(ExchangeEvent)
    /// v2. Recorded after the command's last exchange.
    case command(CommandEvent)
    /// v2.
    case hostStep(HostStepEvent)
    /// v2. An NFCCTAP status update (SW `9100`).
    case status(t: Int64, value: NFCCTAPStatus)
    /// v2.
    case warning(WarningEvent)
    case sessionEnded(t: Int64, reason: SessionEndReason)
    /// v2.
    case scenarioEnded(t: Int64)
}

extension TraceEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, t, reason, value
    }

    private enum EventType: String, Codable {
        case scenarioStarted, sessionStarted, cardDetected, exchange, command, hostStep, status, warning
        case sessionEnded, scenarioEnded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EventType.self, forKey: .type) {
        case .scenarioStarted:
            self = .scenarioStarted(t: try container.decode(Int64.self, forKey: .t))
        case .sessionStarted:
            self = .sessionStarted(t: try container.decode(Int64.self, forKey: .t))
        case .cardDetected:
            self = .cardDetected(t: try container.decode(Int64.self, forKey: .t))
        case .exchange:
            self = .exchange(try ExchangeEvent(from: decoder))
        case .command:
            self = .command(try CommandEvent(from: decoder))
        case .hostStep:
            self = .hostStep(try HostStepEvent(from: decoder))
        case .status:
            self = .status(
                t: try container.decode(Int64.self, forKey: .t),
                value: NFCCTAPStatus(traceValue: try container.decode(String.self, forKey: .value))
            )
        case .warning:
            self = .warning(try WarningEvent(from: decoder))
        case .sessionEnded:
            self = .sessionEnded(
                t: try container.decode(Int64.self, forKey: .t),
                reason: try container.decode(SessionEndReason.self, forKey: .reason)
            )
        case .scenarioEnded:
            self = .scenarioEnded(t: try container.decode(Int64.self, forKey: .t))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .scenarioStarted(t):
            try container.encode(EventType.scenarioStarted, forKey: .type)
            try container.encode(t, forKey: .t)
        case let .sessionStarted(t):
            try container.encode(EventType.sessionStarted, forKey: .type)
            try container.encode(t, forKey: .t)
        case let .cardDetected(t):
            try container.encode(EventType.cardDetected, forKey: .type)
            try container.encode(t, forKey: .t)
        case let .exchange(exchange):
            try container.encode(EventType.exchange, forKey: .type)
            try exchange.encode(to: encoder)
        case let .command(command):
            try container.encode(EventType.command, forKey: .type)
            try command.encode(to: encoder)
        case let .hostStep(step):
            try container.encode(EventType.hostStep, forKey: .type)
            try step.encode(to: encoder)
        case let .status(t, value):
            try container.encode(EventType.status, forKey: .type)
            try container.encode(t, forKey: .t)
            try container.encode(value.traceValue, forKey: .value)
        case let .warning(warning):
            try container.encode(EventType.warning, forKey: .type)
            try warning.encode(to: encoder)
        case let .sessionEnded(t, reason):
            try container.encode(EventType.sessionEnded, forKey: .type)
            try container.encode(t, forKey: .t)
            try container.encode(reason, forKey: .reason)
        case let .scenarioEnded(t):
            try container.encode(EventType.scenarioEnded, forKey: .type)
            try container.encode(t, forKey: .t)
        }
    }
}
