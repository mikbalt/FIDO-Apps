/// One place where decoded CBOR is valid but not in CTAP2 canonical form.
public struct CanonicalityViolation: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        /// An integer encoded with more bytes than needed, e.g. `18 05` for 5.
        case nonShortestInteger
        /// A string, array or map length encoded with more bytes than needed.
        case nonShortestLength
        /// A map key that does not sort after the previous key.
        case unsortedKeys
    }

    public var kind: Kind
    /// Byte offset of the offending item (for `unsortedKeys`, the out-of-order key).
    public var offset: Int

    public init(kind: Kind, offset: Int) {
        self.kind = kind
        self.offset = offset
    }
}

extension CanonicalityViolation: CustomStringConvertible {
    public var description: String {
        switch kind {
        case .nonShortestInteger: "Integer at byte \(offset) is not in its shortest form."
        case .nonShortestLength: "Length at byte \(offset) is not in its shortest form."
        case .unsortedKeys: "Map key at byte \(offset) is out of canonical order."
        }
    }
}
