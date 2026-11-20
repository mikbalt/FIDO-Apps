/// The code of a trace `warning`. An open set, so later briefs can add codes; readers keep unknown ones.
public struct TraceWarningCode: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The card answered an extended-form command with `61xx` instead of returning all data at once.
    public static let extendedFormChained = TraceWarningCode(rawValue: "EXTENDED_FORM_CHAINED")
}
