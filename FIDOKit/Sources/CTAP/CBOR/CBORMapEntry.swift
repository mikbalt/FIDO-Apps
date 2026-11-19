/// One key–value pair of a CBOR map.
public struct CBORMapEntry: Hashable, Sendable {
    public var key: CBORValue
    public var value: CBORValue

    public init(key: CBORValue, value: CBORValue) {
        self.key = key
        self.value = value
    }
}
