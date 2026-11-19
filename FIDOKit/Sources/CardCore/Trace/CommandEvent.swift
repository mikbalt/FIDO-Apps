/// One logical command: every physical exchange it took, with its final result.
public struct CommandEvent: Codable, Sendable, Equatable {
    public var commandIndex: Int
    public var label: String
    /// The CTAP command byte, for commands sent through NFCCTAP_MSG.
    public var ctapCommand: UInt8?
    /// The CTAP status byte of the response, when the final SW is `9000` and the body is not empty.
    public var ctapStatus: UInt8?
    /// The final status word.
    public var sw: StatusWord
    /// `tStart` of the first exchange.
    public var tStart: Int64
    /// `tEnd` of the last exchange.
    public var tEnd: Int64
    /// The `index` of each physical exchange, in order.
    public var exchanges: [Int]

    public init(
        commandIndex: Int, label: String, ctapCommand: UInt8? = nil, ctapStatus: UInt8? = nil,
        sw: StatusWord, tStart: Int64, tEnd: Int64, exchanges: [Int]
    ) {
        self.commandIndex = commandIndex
        self.label = label
        self.ctapCommand = ctapCommand
        self.ctapStatus = ctapStatus
        self.sw = sw
        self.tStart = tStart
        self.tEnd = tEnd
        self.exchanges = exchanges
    }

    /// `tEnd − tStart`: the exchanges plus the time between them (e.g. `9100` polling).
    public var duration: Int64 { tEnd - tStart }

    private enum CodingKeys: String, CodingKey {
        case commandIndex, label, ctapCommand, ctapStatus, sw, tStart, tEnd, exchanges
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        commandIndex = try container.decode(Int.self, forKey: .commandIndex)
        label = try container.decode(String.self, forKey: .label)
        ctapCommand = try Self.decodeByte(.ctapCommand, in: container)
        ctapStatus = try Self.decodeByte(.ctapStatus, in: container)
        sw = try container.decode(StatusWord.self, forKey: .sw)
        tStart = try container.decode(Int64.self, forKey: .tStart)
        tEnd = try container.decode(Int64.self, forKey: .tEnd)
        exchanges = try container.decode([Int].self, forKey: .exchanges)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commandIndex, forKey: .commandIndex)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(ctapCommand.map(Hex.byte), forKey: .ctapCommand)
        try container.encodeIfPresent(ctapStatus.map(Hex.byte), forKey: .ctapStatus)
        try container.encode(sw, forKey: .sw)
        try container.encode(tStart, forKey: .tStart)
        try container.encode(tEnd, forKey: .tEnd)
        try container.encode(exchanges, forKey: .exchanges)
    }

    /// One byte as two hex digits, e.g. `"04"`.
    private static func decodeByte(_ key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) throws -> UInt8? {
        guard let string = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        let bytes = try Hex.parse(string)
        guard bytes.count == 1, let byte = bytes.first else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Expected one hex byte.")
        }
        return byte
    }
}
