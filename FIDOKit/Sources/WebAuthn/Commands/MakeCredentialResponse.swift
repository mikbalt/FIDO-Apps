import CTAP
import Foundation

/// The authenticatorMakeCredential response `{1: fmt, 2: authData, 3: attStmt}`.
public struct MakeCredentialResponse: Sendable, Equatable {
    public let format: String
    public let authenticatorData: Data
    public let attestationStatement: CBORValue

    public init(format: String, authenticatorData: Data, attestationStatement: CBORValue) {
        self.format = format
        self.authenticatorData = authenticatorData
        self.attestationStatement = attestationStatement
    }

    init(decoding body: CBORValue?) throws {
        guard let format = body?[1]?.textValue, let authData = body?[2]?.bytesValue, let statement = body?[3] else {
            throw WebAuthnError.invalidResponse(label: "MAKE_CREDENTIAL", reason: "Missing fmt, authData or attStmt.")
        }
        self.init(format: format, authenticatorData: authData, attestationStatement: statement)
    }

    /// The WebAuthn `attestationObject`: a CBOR map with the text keys `fmt`, `attStmt` and `authData`.
    public func attestationObject() throws -> Data {
        let object: CBORValue = ["fmt": .text(format), "attStmt": attestationStatement, "authData": .bytes(authenticatorData)]
        do {
            return try CBOREncoder.encode(object)
        } catch {
            throw WebAuthnError.invalidCBOR("The attestation statement cannot be encoded.")
        }
    }
}
