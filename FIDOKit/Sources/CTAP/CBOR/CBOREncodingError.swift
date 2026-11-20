public enum CBOREncodingError: Error, Equatable, Sendable {
    /// A map has the same key twice.
    case duplicateKey(CBORValue)
}

extension CBOREncodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .duplicateKey(key): "Duplicate CBOR map key \(key)."
        }
    }
}
