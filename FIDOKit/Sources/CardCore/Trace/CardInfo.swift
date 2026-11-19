import Foundation

public struct CardInfo: Sendable, Equatable {
    public var label: String
    /// The AID the OS selected during discovery (iOS only), before any app exchange.
    public var initialSelectedAID: Data?

    public init(label: String, initialSelectedAID: Data?) {
        self.label = label
        self.initialSelectedAID = initialSelectedAID
    }
}

/// `initialSelectedAID` is encoded as uppercase hex, or `null` when absent.
extension CardInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case label, initialSelectedAID
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        initialSelectedAID = try container.decodeIfPresent(String.self, forKey: .initialSelectedAID)
            .map(Hex.parse)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(initialSelectedAID.map(Hex.compact), forKey: .initialSelectedAID)
    }
}
