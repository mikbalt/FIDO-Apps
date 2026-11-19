/// How exchange bytes are shown. A decoded view comes in brief 02.
enum ExchangeDisplayMode: String, CaseIterable, Identifiable {
    /// All bytes in hex, including sensitive exchanges.
    case hex
    /// Sensitive exchanges are shown as `<redacted N bytes>`.
    case safe

    var id: Self { self }

    var title: String {
        switch self {
        case .hex: "Hex"
        case .safe: "Safe"
        }
    }

    var hidesSensitive: Bool { self == .safe }
}
