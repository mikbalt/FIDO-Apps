/// Names for the keys of a CBOR map, used to annotate diagnostic notation (`1 /versions/: [...]`).
/// Command models provide one for their request and response maps.
public struct CBORSchema: Sendable {
    public var names: [CBORValue: String]
    /// Schemas for the values of specific keys, when those values are maps themselves.
    public var children: [CBORValue: CBORSchema]

    public init(names: [CBORValue: String], children: [CBORValue: CBORSchema] = [:]) {
        self.names = names
        self.children = children
    }
}
