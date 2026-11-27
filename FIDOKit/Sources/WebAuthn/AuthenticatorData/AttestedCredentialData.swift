import Foundation

/// The attested credential data of a registration authData: AAGUID, credential ID and the COSE key.
public struct AttestedCredentialData: Sendable, Equatable {
    public let aaguid: Data
    public let credentialId: Data
    /// The COSE key bytes exactly as the card sent them.
    public let publicKeyCOSE: Data
    /// The key as ES256, or the reason it is not one. A key of another algorithm still parses as authData.
    public let publicKey: Result<ES256PublicKey, WebAuthnError>

    public static func == (lhs: AttestedCredentialData, rhs: AttestedCredentialData) -> Bool {
        lhs.aaguid == rhs.aaguid && lhs.credentialId == rhs.credentialId && lhs.publicKeyCOSE == rhs.publicKeyCOSE
    }
}
