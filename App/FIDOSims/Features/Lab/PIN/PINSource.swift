/// Where a PIN input comes from. The default `1234` is a UI default only; the SDK never assumes it.
enum PINSource: String, CaseIterable, Identifiable {
    case defaultPIN
    case custom
    case stored

    static let defaultValue = "1234"

    var id: Self { self }

    var title: String {
        switch self {
        case .defaultPIN: "Default (\(Self.defaultValue))"
        case .custom: "Custom"
        case .stored: "Stored"
        }
    }
}
