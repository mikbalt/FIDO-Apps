import Foundation

/// The `toJSON()` of an assertion (`AuthenticationResponseJSON`). Encode with `WebAuthnJSON.encoder()`.
public struct AuthenticationResultJSON: Codable, Sendable, Equatable {
    public struct Response: Codable, Sendable, Equatable {
        public var clientDataJSON: Data
        public var authenticatorData: Data
        public var signature: Data
        public var userHandle: Data?
    }

    public var id: String
    public var rawId: Data
    public var type: String
    public var response: Response

    /// `credentialId` is the ID of the credential that was asked for; the card's own answer wins if it sent one.
    public init(credentialId: Data, clientDataJSON: Data, response: GetAssertionResponse) {
        let id = response.credentialId ?? credentialId
        self.id = id.base64URLEncoded
        rawId = id
        type = "public-key"
        self.response = Response(
            clientDataJSON: clientDataJSON, authenticatorData: response.authenticatorData,
            signature: response.signature, userHandle: response.userHandle
        )
    }
}
