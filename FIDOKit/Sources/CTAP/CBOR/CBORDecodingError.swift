/// Why a byte sequence is not CBOR this decoder accepts. `offset` is where the offending item starts.
public enum CBORDecodingError: Error, Equatable, Sendable {
    /// The input ends inside an item.
    case truncated(offset: Int)
    /// Floating-point numbers (major type 7, additional info 25–27) are not used by CTAP.
    case floatNotSupported(offset: Int)
    /// Tags (major type 6) are not used by CTAP.
    case tagNotSupported(offset: Int)
    /// The simple value `undefined` (`F7`).
    case undefinedNotSupported(offset: Int)
    /// Any other simple value.
    case simpleValueNotSupported(value: UInt8, offset: Int)
    /// Indefinite-length strings, arrays or maps (additional info 31), or a stray break byte (`FF`).
    case indefiniteLength(offset: Int)
    /// Additional info 28–30, which CBOR reserves.
    case reservedAdditionalInfo(offset: Int)
    /// A text string that is not valid UTF-8.
    case invalidUTF8(offset: Int)
    /// A map has the same key twice. Unlike ordering, this makes the map ambiguous, so it is an error.
    case duplicateKey(offset: Int)
    /// More nested arrays and maps than the decoder allows.
    case nestingTooDeep(offset: Int)
    /// A length does not fit in memory.
    case lengthTooLarge(offset: Int)
    /// `decodeExactly` found bytes after the item.
    case trailingBytes(offset: Int)
}

extension CBORDecodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .truncated(offset): "CBOR input ends inside the item at byte \(offset)."
        case let .floatNotSupported(offset): "CBOR float at byte \(offset) is not supported."
        case let .tagNotSupported(offset): "CBOR tag at byte \(offset) is not supported."
        case let .undefinedNotSupported(offset): "CBOR undefined at byte \(offset) is not supported."
        case let .simpleValueNotSupported(value, offset): "CBOR simple value \(value) at byte \(offset) is not supported."
        case let .indefiniteLength(offset): "CBOR indefinite length at byte \(offset) is not allowed."
        case let .reservedAdditionalInfo(offset): "Reserved CBOR additional info at byte \(offset)."
        case let .invalidUTF8(offset): "CBOR text string at byte \(offset) is not valid UTF-8."
        case let .duplicateKey(offset): "Duplicate CBOR map key at byte \(offset)."
        case let .nestingTooDeep(offset): "CBOR nesting too deep at byte \(offset)."
        case let .lengthTooLarge(offset): "CBOR length at byte \(offset) is too large."
        case let .trailingBytes(offset): "Unexpected bytes after the CBOR item, from byte \(offset)."
        }
    }
}
