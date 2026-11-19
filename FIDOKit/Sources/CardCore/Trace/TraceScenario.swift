/// What a trace's session was for. Values this version does not know decode as `.unknown(raw)`.
public enum TraceScenario: Hashable, Sendable {
    case diagnostics
    case setPIN
    case changePIN
    case reset
    case register
    case authenticate
    /// Hand-built APDUs or low-level channel use, e.g. tests.
    case raw
    case unknown(String)

    public static let known: [TraceScenario] = [
        .diagnostics, .setPIN, .changePIN, .reset, .register, .authenticate, .raw,
    ]

    public init(rawValue: String) {
        self = Self.known.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    public var rawValue: String {
        switch self {
        case .diagnostics: "diagnostics"
        case .setPIN: "setPIN"
        case .changePIN: "changePIN"
        case .reset: "reset"
        case .register: "register"
        case .authenticate: "authenticate"
        case .raw: "raw"
        case let .unknown(raw): raw
        }
    }
}

extension TraceScenario: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
