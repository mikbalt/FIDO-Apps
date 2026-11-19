import Foundation

/// One physical APDU command–response.
public struct ExchangeEvent: Sendable, Equatable, Identifiable {
    /// 1-based; counts physical APDUs in the session.
    public var index: Int
    /// 1-based index of the logical command this exchange belongs to.
    public var commandIndex: Int
    /// Label of the logical command, e.g. `SELECT_FIDO`, `GET_INFO`.
    public var label: String
    public var tx: Data
    /// Response data, without the status word.
    public var rx: Data
    public var sw: StatusWord
    /// Nanoseconds since `sessionStarted`, immediately before the I/O call.
    public var tStart: Int64
    /// Nanoseconds since `sessionStarted`, immediately after the I/O call returned.
    public var tEnd: Int64
    public var sensitive: Bool
    /// `tx` and `rx` were replaced by zero bytes of the same length. In JSON, a redacted exchange has
    /// `"tx": null`, `"rx": null`, `txLength`, `rxLength` and `"redacted": true`.
    public var isRedacted: Bool

    public init(
        index: Int,
        commandIndex: Int,
        label: String,
        tx: Data,
        rx: Data,
        sw: StatusWord,
        tStart: Int64,
        tEnd: Int64,
        sensitive: Bool,
        isRedacted: Bool = false
    ) {
        self.index = index
        self.commandIndex = commandIndex
        self.label = label
        self.tx = tx
        self.rx = rx
        self.sw = sw
        self.tStart = tStart
        self.tEnd = tEnd
        self.sensitive = sensitive
        self.isRedacted = isRedacted
    }

    public var id: Int { index }

    /// Round-trip time in nanoseconds.
    public var rtt: Int64 { tEnd - tStart }

    /// A copy with the bytes removed, keeping only their lengths.
    public func redacted() -> ExchangeEvent {
        var copy = self
        copy.tx = Data(count: tx.count)
        copy.rx = Data(count: rx.count)
        copy.isRedacted = true
        return copy
    }

    /// Display form of `tx`: spaced hex, or a placeholder when redacted or hidden.
    public func txDisplay(hideSensitive: Bool) -> String {
        display(tx, hideSensitive: hideSensitive)
    }

    /// Display form of `rx`: spaced hex, or a placeholder when redacted or hidden.
    public func rxDisplay(hideSensitive: Bool) -> String {
        display(rx, hideSensitive: hideSensitive)
    }

    private func display(_ bytes: Data, hideSensitive: Bool) -> String {
        if isRedacted || (sensitive && hideSensitive) {
            return Redaction.placeholder(byteCount: bytes.count)
        }
        return Hex.format(bytes)
    }
}

extension ExchangeEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case index, commandIndex, label, tx, rx, txLength, rxLength, redacted, sw, tStart, tEnd, sensitive
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        index = try container.decode(Int.self, forKey: .index)
        commandIndex = try container.decode(Int.self, forKey: .commandIndex)
        label = try container.decode(String.self, forKey: .label)
        sw = try container.decode(StatusWord.self, forKey: .sw)
        tStart = try container.decode(Int64.self, forKey: .tStart)
        tEnd = try container.decode(Int64.self, forKey: .tEnd)
        sensitive = try container.decode(Bool.self, forKey: .sensitive)
        isRedacted = try container.decodeIfPresent(Bool.self, forKey: .redacted) ?? false

        if isRedacted {
            for key in [CodingKeys.tx, .rx] {
                guard try container.decodeNil(forKey: key) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: key, in: container, debugDescription: "A redacted exchange must have null bytes."
                    )
                }
            }
            tx = Data(count: try Self.decodeLength(.txLength, in: container))
            rx = Data(count: try Self.decodeLength(.rxLength, in: container))
        } else {
            tx = try Hex.parse(container.decode(String.self, forKey: .tx))
            rx = try Hex.parse(container.decode(String.self, forKey: .rx))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(index, forKey: .index)
        try container.encode(commandIndex, forKey: .commandIndex)
        try container.encode(label, forKey: .label)
        if isRedacted {
            try container.encodeNil(forKey: .tx)
            try container.encodeNil(forKey: .rx)
            try container.encode(tx.count, forKey: .txLength)
            try container.encode(rx.count, forKey: .rxLength)
            try container.encode(true, forKey: .redacted)
        } else {
            try container.encode(Hex.compact(tx), forKey: .tx)
            try container.encode(Hex.compact(rx), forKey: .rx)
        }
        try container.encode(sw, forKey: .sw)
        try container.encode(tStart, forKey: .tStart)
        try container.encode(tEnd, forKey: .tEnd)
        try container.encode(sensitive, forKey: .sensitive)
    }

    private static func decodeLength(_ key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>) throws -> Int {
        let length = try container.decode(Int.self, forKey: key)
        guard length >= 0 else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Negative length.")
        }
        return length
    }
}
