import Foundation

/// `PublicKeyCredentialCreationOptionsJSON`. Encode with `WebAuthnJSON.encoder()`.
public struct CreationOptions: Codable, Sendable, Equatable {
    public struct RelyingParty: Codable, Sendable, Equatable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct User: Codable, Sendable, Equatable {
        public var id: Data
        public var name: String
        public var displayName: String

        public init(id: Data, name: String, displayName: String) {
            self.id = id
            self.name = name
            self.displayName = displayName
        }
    }

    public struct AuthenticatorSelection: Codable, Sendable, Equatable {
        public var residentKey: String?
        public var requireResidentKey: Bool?
        public var userVerification: String?

        public init(residentKey: String? = nil, requireResidentKey: Bool? = nil, userVerification: String? = nil) {
            self.residentKey = residentKey
            self.requireResidentKey = requireResidentKey
            self.userVerification = userVerification
        }
    }

    public var rp: RelyingParty
    public var user: User
    public var challenge: Data
    public var pubKeyCredParams: [CredentialParameters]
    public var authenticatorSelection: AuthenticatorSelection?
    public var attestation: String

    public init(
        rp: RelyingParty, user: User, challenge: Data, pubKeyCredParams: [CredentialParameters] = [.es256],
        authenticatorSelection: AuthenticatorSelection? = nil, attestation: String = "none"
    ) {
        self.rp = rp
        self.user = user
        self.challenge = challenge
        self.pubKeyCredParams = pubKeyCredParams
        self.authenticatorSelection = authenticatorSelection
        self.attestation = attestation
    }

    /// True when the options ask for a discoverable credential.
    public var requiresResidentKey: Bool {
        authenticatorSelection?.residentKey == "required" || authenticatorSelection?.requireResidentKey == true
    }
}
