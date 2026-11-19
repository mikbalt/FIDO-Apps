enum TransportChoice: String, CaseIterable, Identifiable {
    case nfc
    case mock

    var id: Self { self }

    var title: String {
        switch self {
        case .nfc: "NFC"
        case .mock: "Mock"
        }
    }
}
