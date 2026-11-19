import Foundation

/// A CBOR data item, limited to the types CTAP2 uses.
///
/// Maps keep their entries in the order they were built or decoded. The encoder sorts them canonically,
/// so building a map in any order is fine.
public indirect enum CBORValue: Hashable, Sendable {
    /// Major type 0.
    case unsigned(UInt64)
    /// Major type 1. The value is `-1 - n`, so the full range −2⁶⁴ … −1 is representable.
    case negative(UInt64)
    /// Major type 2.
    case bytes(Data)
    /// Major type 3.
    case text(String)
    /// Major type 4.
    case array([CBORValue])
    /// Major type 5.
    case map([CBORMapEntry])
    /// Simple values 20 and 21.
    case bool(Bool)
    /// Simple value 22.
    case null

    /// An integer value.
    public init(_ value: Int) {
        self = value >= 0 ? .unsigned(UInt64(value)) : .negative(UInt64(-(value + 1)))
    }

    // MARK: Accessors

    /// The integer value, if it is an integer that fits in `Int`.
    public var intValue: Int? {
        switch self {
        case let .unsigned(value): value <= UInt64(Int.max) ? Int(value) : nil
        case let .negative(value): value <= UInt64(Int.max) ? -1 - Int(value) : nil
        default: nil
        }
    }

    /// The value of an unsigned integer.
    public var unsignedValue: UInt64? {
        if case let .unsigned(value) = self { value } else { nil }
    }

    public var bytesValue: Data? {
        if case let .bytes(value) = self { value } else { nil }
    }

    public var textValue: String? {
        if case let .text(value) = self { value } else { nil }
    }

    public var arrayValue: [CBORValue]? {
        if case let .array(value) = self { value } else { nil }
    }

    public var mapEntries: [CBORMapEntry]? {
        if case let .map(value) = self { value } else { nil }
    }

    public var boolValue: Bool? {
        if case let .bool(value) = self { value } else { nil }
    }

    public var isNull: Bool { self == .null }

    /// The value for `key` in a map, or `nil` if this is not a map or the key is absent.
    public subscript(key: CBORValue) -> CBORValue? {
        mapEntries?.first { $0.key == key }?.value
    }

    /// The CBOR major type (0–7).
    public var majorType: UInt8 {
        switch self {
        case .unsigned: 0
        case .negative: 1
        case .bytes: 2
        case .text: 3
        case .array: 4
        case .map: 5
        case .bool, .null: 7
        }
    }
}

extension CBORValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension CBORValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension CBORValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension CBORValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension CBORValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: CBORValue...) {
        self = .array(elements)
    }
}

/// Keeps the written order and duplicates, so the encoder can sort and reject duplicate keys.
extension CBORValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (CBORValue, CBORValue)...) {
        self = .map(elements.map { CBORMapEntry(key: $0.0, value: $0.1) })
    }
}

extension CBORValue: CustomStringConvertible {
    /// Diagnostic notation.
    public var description: String { CBORDiagnostic.format(self) }
}
