import Foundation

/// The `toJSON()` of a created credential (`RegistrationResponseJSON`). Encode with `WebAuthnJSON.encoder()`.
public struct RegistrationResultJSON: Codable, Sendable, Equatable {
    public struct Response: Codable, Sendable, Equatable {
        public var clientDataJSON: Data
        public var attestationObject: Data
        public var authenticatorData: Data
        public var transports: [String]
        public var publicKeyAlgorithm: Int
    }

    public var id: String
    public var rawId: Data
    public var type: String
    public var response: Response

    /// Builds the result for a credential made over NFC with ES256.
    public init(credentialId: Data, clientDataJSON: Data, response: MakeCredentialResponse) throws {
        id = credentialId.base64URLEncoded
        rawId = credentialId
        type = "public-key"
        self.response = Response(
            clientDataJSON: clientDataJSON, attestationObject: try response.attestationObject(),
            authenticatorData: response.authenticatorData, transports: ["nfc"], publicKeyAlgorithm: -7
        )
    }
}
