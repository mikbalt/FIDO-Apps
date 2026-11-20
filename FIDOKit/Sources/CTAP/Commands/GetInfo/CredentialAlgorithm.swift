/// One entry of GetInfo `algorithms` (key `0x0A`): a `PublicKeyCredentialParameters` map.
public struct CredentialAlgorithm: Sendable, Equatable {
    public var type: String
    /// COSE algorithm identifier, e.g. `-7` for ES256.
    public var alg: Int

    public init(type: String = "public-key", alg: Int) {
        self.type = type
        self.alg = alg
    }

    public static let es256 = CredentialAlgorithm(alg: -7)

    /// The usual name, e.g. `ES256`, or the number.
    public var name: String {
        switch alg {
        case -7: "ES256"
        case -8: "EdDSA"
        case -35: "ES384"
        case -36: "ES512"
        case -257: "RS256"
        default: "\(alg)"
        }
    }
}
