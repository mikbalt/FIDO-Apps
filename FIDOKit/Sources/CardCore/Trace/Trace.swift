import Foundation

/// Metadata plus ordered events for one session. See `docs/trace-format.md`.
public struct Trace: Sendable, Equatable, Identifiable {
    public static let currentSchemaVersion = 2
    /// Versions this build reads. v1 traces decode unchanged.
    public static let supportedSchemaVersions = 1...2

    public var schemaVersion: Int
    public var id: UUID
    /// Wall-clock time, for display only. Whole seconds, so it survives the JSON round trip.
    public var createdAt: Date
    public var app: AppInfo
    public var transport: TransportKind
    public var device: DeviceInfo
    /// v2. `nil` for v1 traces.
    public var scenario: TraceScenario?
    /// v2. `nil` for v1 traces, and while a scenario is still running.
    public var outcome: TraceOutcome?
    public var card: CardInfo
    public var options: TraceOptions
    public var events: [TraceEvent]

    public init(
        schemaVersion: Int = Trace.currentSchemaVersion,
        id: UUID,
        createdAt: Date,
        app: AppInfo,
        transport: TransportKind,
        device: DeviceInfo,
        scenario: TraceScenario? = nil,
        outcome: TraceOutcome? = nil,
        card: CardInfo,
        options: TraceOptions,
        events: [TraceEvent]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.createdAt = createdAt
        self.app = app
        self.transport = transport
        self.device = device
        self.scenario = scenario
        self.outcome = outcome
        self.card = card
        self.options = options
        self.events = events
    }

    public var exchanges: [ExchangeEvent] {
        events.compactMap { event in
            if case let .exchange(exchange) = event { exchange } else { nil }
        }
    }

    public var warnings: [WarningEvent] {
        events.compactMap { event in
            if case let .warning(warning) = event { warning } else { nil }
        }
    }

    public var sessionStartedTime: Int64? {
        events.lazy.compactMap { event in
            if case let .sessionStarted(t) = event { t } else { nil }
        }.first
    }

    public var cardDetectedTime: Int64? {
        events.lazy.compactMap { event in
            if case let .cardDetected(t) = event { t } else { nil }
        }.first
    }

    public var endReason: SessionEndReason? {
        events.lazy.compactMap { event in
            if case let .sessionEnded(_, reason) = event { reason } else { nil }
        }.first
    }

    /// A copy where every sensitive exchange has its bytes replaced by their length.
    public func redactingSensitive() -> Trace {
        var copy = self
        copy.events = events.map { event in
            if case let .exchange(exchange) = event, exchange.sensitive {
                .exchange(exchange.redacted())
            } else {
                event
            }
        }
        return copy
    }
}

extension Trace: Codable {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, createdAt, app, transport, device, scenario, outcome, card, options, events
    }

    private static let dateStyle = Date.ISO8601FormatStyle()

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard Self.supportedSchemaVersions.contains(schemaVersion) else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: container,
                debugDescription: "Unsupported trace schema version \(schemaVersion); this build reads "
                    + "\(Self.supportedSchemaVersions.lowerBound)–\(Self.supportedSchemaVersions.upperBound)."
            )
        }
        id = try container.decode(UUID.self, forKey: .id)
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        do {
            createdAt = try Self.dateStyle.parse(createdAtString)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .createdAt, in: container,
                debugDescription: "Expected an ISO 8601 date such as 2026-11-20T09:15:02Z."
            )
        }
        app = try container.decode(AppInfo.self, forKey: .app)
        transport = try container.decode(TransportKind.self, forKey: .transport)
        device = try container.decode(DeviceInfo.self, forKey: .device)
        scenario = try container.decodeIfPresent(TraceScenario.self, forKey: .scenario)
        outcome = try container.decodeIfPresent(TraceOutcome.self, forKey: .outcome)
        card = try container.decode(CardInfo.self, forKey: .card)
        options = try container.decode(TraceOptions.self, forKey: .options)
        events = try container.decode([TraceEvent].self, forKey: .events)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt.formatted(Self.dateStyle), forKey: .createdAt)
        try container.encode(app, forKey: .app)
        try container.encode(transport, forKey: .transport)
        try container.encode(device, forKey: .device)
        try container.encodeIfPresent(scenario, forKey: .scenario)
        try container.encodeIfPresent(outcome, forKey: .outcome)
        try container.encode(card, forKey: .card)
        try container.encode(options, forKey: .options)
        try container.encode(events, forKey: .events)
    }
}
