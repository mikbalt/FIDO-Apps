public enum CBOREncodingError: Error, Equatable, Sendable {
    /// A map has the same key twice.
    case duplicateKey(CBORValue)
    /// Arrays and maps nest deeper than the allowed number of levels.
    case nestingTooDeep(limit: Int)
}

extension CBOREncodingError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .duplicateKey(key): "Duplicate CBOR map key \(key)."
        case let .nestingTooDeep(limit): "CBOR nesting deeper than \(limit) levels."
        }
    }
}
