import CTAP
import Foundation

/// The authenticatorGetAssertion response `{1: credential?, 2: authData, 3: signature, 4: user?}`.
public struct GetAssertionResponse: Sendable, Equatable {
    /// The credential ID the card answered with. Optional in CTAP when the allowList had one entry.
    public let credentialId: Data?
    public let authenticatorData: Data
    /// DER-encoded ECDSA signature over `authenticatorData ‖ clientDataHash`.
    public let signature: Data
    public let userHandle: Data?

    public init(credentialId: Data?, authenticatorData: Data, signature: Data, userHandle: Data?) {
        self.credentialId = credentialId
        self.authenticatorData = authenticatorData
        self.signature = signature
        self.userHandle = userHandle
    }

    init(decoding body: CBORValue?) throws {
        guard let authData = body?[2]?.bytesValue, let signature = body?[3]?.bytesValue else {
            throw WebAuthnError.invalidResponse(label: "GET_ASSERTION", reason: "Missing authData or signature.")
        }
        self.init(
            credentialId: body?[1]?["id"]?.bytesValue, authenticatorData: authData, signature: signature,
            userHandle: body?[4]?["id"]?.bytesValue
        )
    }
}
