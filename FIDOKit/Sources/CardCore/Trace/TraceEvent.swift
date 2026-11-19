/// An ordered event in a trace. Times are monotonic nanoseconds since `sessionStarted`.
public enum TraceEvent: Sendable, Equatable {
    case sessionStarted(t: Int64)
    case cardDetected(t: Int64)
    case exchange(ExchangeEvent)
    case sessionEnded(t: Int64, reason: SessionEndReason)
}

extension TraceEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, t, reason
    }

    private enum EventType: String, Codable {
        case sessionStarted, cardDetected, exchange, sessionEnded
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(EventType.self, forKey: .type) {
        case .sessionStarted:
            self = .sessionStarted(t: try container.decode(Int64.self, forKey: .t))
        case .cardDetected:
            self = .cardDetected(t: try container.decode(Int64.self, forKey: .t))
        case .exchange:
            self = .exchange(try ExchangeEvent(from: decoder))
        case .sessionEnded:
            self = .sessionEnded(
                t: try container.decode(Int64.self, forKey: .t),
                reason: try container.decode(SessionEndReason.self, forKey: .reason)
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .sessionStarted(t):
            try container.encode(EventType.sessionStarted, forKey: .type)
            try container.encode(t, forKey: .t)
        case let .cardDetected(t):
            try container.encode(EventType.cardDetected, forKey: .type)
            try container.encode(t, forKey: .t)
        case let .exchange(exchange):
            try container.encode(EventType.exchange, forKey: .type)
            try exchange.encode(to: encoder)
        case let .sessionEnded(t, reason):
            try container.encode(EventType.sessionEnded, forKey: .type)
            try container.encode(t, forKey: .t)
            try container.encode(reason, forKey: .reason)
        }
    }
}
