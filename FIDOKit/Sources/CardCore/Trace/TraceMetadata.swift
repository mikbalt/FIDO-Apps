import Foundation

/// Everything a `TraceRecorder` needs besides the connection and the exchanges.
public struct TraceMetadata: Sendable {
    public var id: UUID
    public var createdAt: Date
    public var app: AppInfo
    public var transport: TransportKind
    public var device: DeviceInfo
    /// v2. `nil` for low-level channel use outside a scenario (tests).
    public var scenario: TraceScenario?
    public var cardLabel: String
    public var options: TraceOptions

    public init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        app: AppInfo = .current(),
        transport: TransportKind,
        device: DeviceInfo = .current,
        scenario: TraceScenario? = nil,
        cardLabel: String,
        options: TraceOptions
    ) {
        self.id = id
        // Whole seconds: the JSON format has no fractional seconds.
        self.createdAt = Date(timeIntervalSince1970: createdAt.timeIntervalSince1970.rounded(.down))
        self.app = app
        self.transport = transport
        self.device = device
        self.scenario = scenario
        self.cardLabel = cardLabel
        self.options = options
    }
}
