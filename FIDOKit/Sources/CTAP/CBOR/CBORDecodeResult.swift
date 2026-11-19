/// The outcome of decoding one CBOR item from the start of a byte sequence.
public struct CBORDecodeResult: Hashable, Sendable {
    public var value: CBORValue
    /// Bytes the item occupies. Anything after it is not read.
    public var bytesConsumed: Int
    public var canonicality: CanonicalityReport

    public init(value: CBORValue, bytesConsumed: Int, canonicality: CanonicalityReport) {
        self.value = value
        self.bytesConsumed = bytesConsumed
        self.canonicality = canonicality
    }
}
