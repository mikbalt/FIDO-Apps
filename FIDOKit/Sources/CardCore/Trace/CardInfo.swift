import Foundation

public struct CardInfo: Sendable, Equatable {
    public var label: String
    /// The AID the OS selected during discovery (iOS only), before any app exchange.
    public var initialSelectedAID: Data?
    /// From GetInfo (v2). `nil` until GetInfo succeeded.
    public var aaguid: UUID?
    /// From GetInfo (v2), e.g. `["FIDO_2_0", "FIDO_2_1"]`.
    public var versions: [String]?
    /// From GetInfo (v2), when the card reports it.
    public var firmwareVersion: UInt64?

    public init(
        label: String, initialSelectedAID: Data?,
        aaguid: UUID? = nil, versions: [String]? = nil, firmwareVersion: UInt64? = nil
    ) {
        self.label = label
        self.initialSelectedAID = initialSelectedAID
        self.aaguid = aaguid
        self.versions = versions
        self.firmwareVersion = firmwareVersion
    }
}

/// `initialSelectedAID` is uppercase hex, or `null` when absent. `aaguid` is an uppercase UUID string.
/// The v2 fields are omitted when absent, so v1 cards encode exactly as before.
extension CardInfo: Codable {
    private enum CodingKeys: String, CodingKey {
        case label, initialSelectedAID, aaguid, versions, firmwareVersion
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        initialSelectedAID = try container.decodeIfPresent(String.self, forKey: .initialSelectedAID)
            .map(Hex.parse)
        aaguid = try container.decodeIfPresent(UUID.self, forKey: .aaguid)
        versions = try container.decodeIfPresent([String].self, forKey: .versions)
        firmwareVersion = try container.decodeIfPresent(UInt64.self, forKey: .firmwareVersion)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(initialSelectedAID.map(Hex.compact), forKey: .initialSelectedAID)
        try container.encodeIfPresent(aaguid, forKey: .aaguid)
        try container.encodeIfPresent(versions, forKey: .versions)
        try container.encodeIfPresent(firmwareVersion, forKey: .firmwareVersion)
    }
}
