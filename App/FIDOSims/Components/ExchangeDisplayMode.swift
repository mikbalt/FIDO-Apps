/// How a trace is shown.
enum ExchangeDisplayMode: String, CaseIterable, Identifiable {
    /// All bytes in hex, including sensitive exchanges.
    case hex
    /// Sensitive exchanges are shown as `<redacted N bytes>`.
    case safe
    /// One line per command, the GetInfo table and the CBOR of each command. Sensitive payloads stay redacted.
    case decoded

    var id: Self { self }

    var title: String {
        switch self {
        case .hex: "Hex"
        case .safe: "Safe"
        case .decoded: "Decoded"
        }
    }

    var hidesSensitive: Bool { self != .hex }
}
