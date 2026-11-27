import Foundation

/// `PublicKeyCredentialRequestOptionsJSON`. Encode with `WebAuthnJSON.encoder()`.
public struct RequestOptions: Codable, Sendable, Equatable {
    public var rpId: String
    public var challenge: Data
    public var allowCredentials: [CredentialDescriptor]
    public var userVerification: String

    public init(rpId: String, challenge: Data, allowCredentials: [CredentialDescriptor] = [], userVerification: String = "required") {
        self.rpId = rpId
        self.challenge = challenge
        self.allowCredentials = allowCredentials
        self.userVerification = userVerification
    }
}
