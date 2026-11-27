/// One entry of `pubKeyCredParams`.
public struct CredentialParameters: Codable, Sendable, Equatable {
    public var type: String
    public var alg: Int

    public init(type: String = "public-key", alg: Int) {
        self.type = type
        self.alg = alg
    }

    /// ES256 (ECDSA P-256 with SHA-256), the only algorithm FIDOSims uses.
    public static let es256 = CredentialParameters(alg: -7)
}
