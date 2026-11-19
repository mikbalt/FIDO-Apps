/// The code of a trace `warning`. An open set: new codes are added as checks are added.
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

    /// The card rejected NFCCTAP_MSG with P1 = `80` (`6A86` / `6B00`); the session continues with P1 = `00`.
    public static let p1Fallback = TraceWarningCode(rawValue: "P1_FALLBACK")
    /// The card answered an extended-form command with `61xx` instead of returning all data at once.
    public static let extendedFormChained = TraceWarningCode(rawValue: "EXTENDED_FORM_CHAINED")
    /// Response CBOR has an integer in a longer form than needed.
    public static let cborNonShortestInteger = TraceWarningCode(rawValue: "CBOR_NON_SHORTEST_INTEGER")
    /// Response CBOR has a length in a longer form than needed.
    public static let cborNonShortestLength = TraceWarningCode(rawValue: "CBOR_NON_SHORTEST_LENGTH")
    /// Response CBOR has map keys out of canonical order.
    public static let cborUnsortedKeys = TraceWarningCode(rawValue: "CBOR_UNSORTED_KEYS")
    /// The response has bytes after its CBOR item.
    public static let cborTrailingBytes = TraceWarningCode(rawValue: "CBOR_TRAILING_BYTES")
}
