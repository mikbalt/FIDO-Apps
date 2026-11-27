import CryptoKit
import Foundation

/// The minimal local RP: makes the challenge and options, and checks what the card returned.
///
/// ES256 only, attestation `none` (the format is recorded, not verified), PIN always used.
/// It does not store anything: it returns what to save.
public struct LocalRelyingParty: Sendable {
    public static let defaultRpId = "fidosims.example"
    public static let defaultOrigin = "https://fidosims.example"

    public let rpId: String
    public let origin: String
    public let rpName: String
    private let randomBytes: @Sendable (Int) -> Data

    public init(
        rpId: String = defaultRpId, origin: String = defaultOrigin, rpName: String = "FIDOSims",
        randomBytes: @escaping @Sendable (Int) -> Data = { count in
            var generator = SystemRandomNumberGenerator()
            return Data((0..<count).map { _ in UInt8.random(in: 0...255, using: &generator) })
        }
    ) {
        self.rpId = rpId
        self.origin = origin
        self.rpName = rpName
        self.randomBytes = randomBytes
    }

    // MARK: Begin

    /// Creation options with a 32-byte challenge and a 16-byte random user ID.
    public func beginRegistration(username: String, residentKey: Bool = false) -> CreationOptions {
        CreationOptions(
            rp: .init(id: rpId, name: rpName),
            user: .init(id: randomBytes(16), name: username, displayName: username),
            challenge: randomBytes(32),
            pubKeyCredParams: [.es256],
            authenticatorSelection: .init(
                residentKey: residentKey ? "required" : "discouraged", requireResidentKey: residentKey ? true : nil,
                userVerification: "required"),
            attestation: "none"
        )
    }

    /// Request options with a 32-byte challenge for the selected credential.
    public func beginAuthentication(credentialId: Data) -> RequestOptions {
        RequestOptions(
            rpId: rpId, challenge: randomBytes(32), allowCredentials: [CredentialDescriptor(id: credentialId)],
            userVerification: "required")
    }

    // MARK: Verify

    public func verifyRegistration(
        options: CreationOptions, clientDataJSON: Data, response: MakeCredentialResponse, existingCredentialIds: Set<Data>
    ) -> RegistrationVerification {
        var checks = clientDataChecks(.create, challenge: options.challenge, json: clientDataJSON)
        let authData: AuthenticatorData
        do {
            authData = try AuthenticatorData(parsing: response.authenticatorData)
        } catch {
            checks.append(RPCheck(.authenticatorDataParses, passed: false, error.localizedDescription))
            return RegistrationVerification(checks: checks, credential: nil)
        }
        checks += authDataChecks(authData)
        checks.append(RPCheck(.attestedCredentialData, passed: authData.attestedCredentialData != nil,
                              authData.attestedCredentialData != nil ? "Attested credential data present." : "AT flag or data missing."))
        let attested = authData.attestedCredentialData
        switch attested?.publicKey {
        case .success?: checks.append(RPCheck(.publicKeyES256, passed: true, "COSE EC2, ES256, P-256."))
        case let .failure(error)?: checks.append(RPCheck(.publicKeyES256, passed: false, error.localizedDescription))
        case nil: checks.append(RPCheck(.publicKeyES256, passed: false, "No key."))
        }
        if let attested {
            let isNew = !existingCredentialIds.contains(attested.credentialId)
            checks.append(RPCheck(.credentialNew, passed: isNew, isNew ? "Not stored yet." : "Already stored."))
        } else {
            checks.append(RPCheck(.credentialNew, passed: false, "No credential ID."))
        }
        checks.append(RPCheck(.attestationFormat, passed: true, "\(response.format) (recorded, not verified)."))

        guard checks.allSatisfy(\.passed), let attested else { return RegistrationVerification(checks: checks, credential: nil) }
        return RegistrationVerification(
            checks: checks,
            credential: .init(
                credentialId: attested.credentialId, publicKeyCOSE: attested.publicKeyCOSE, aaguid: attested.aaguid,
                signCount: authData.signCount, flags: authData.flags, attestationFormat: response.format)
        )
    }

    public func verifyAuthentication(
        options: RequestOptions, clientDataJSON: Data, response: GetAssertionResponse, stored: KnownCredential?
    ) -> AuthenticationVerification {
        var checks: [RPCheck] = []
        if let stored {
            checks.append(RPCheck(.credentialKnown, passed: !stored.invalidated,
                                  stored.invalidated ? "The credential is invalidated (the card was reset)." : "Stored and valid."))
        } else {
            checks.append(RPCheck(.credentialKnown, passed: false, "Not stored."))
        }
        checks += clientDataChecks(.get, challenge: options.challenge, json: clientDataJSON)
        let authData: AuthenticatorData
        do {
            authData = try AuthenticatorData(parsing: response.authenticatorData)
        } catch {
            checks.append(RPCheck(.authenticatorDataParses, passed: false, error.localizedDescription))
            return AuthenticationVerification(checks: checks, newSignCount: nil)
        }
        checks += authDataChecks(authData)
        checks.append(signatureCheck(response, clientDataJSON: clientDataJSON, stored: stored))
        checks.append(signCountCheck(new: authData.signCount, stored: stored?.signCount))

        return AuthenticationVerification(checks: checks, newSignCount: checks.allSatisfy(\.passed) ? authData.signCount : nil)
    }

    // MARK: Checks

    private func clientDataChecks(_ kind: ClientData.Kind, challenge: Data, json: Data) -> [RPCheck] {
        guard let parsed = try? ParsedClientData(json: json) else {
            return [RPCheck.Name.clientDataType, .challenge, .origin].map { RPCheck($0, passed: false, "clientDataJSON does not parse.") }
        }
        return [
            RPCheck(.clientDataType, passed: parsed.type == kind.rawValue, "\(parsed.type), expected \(kind.rawValue)."),
            RPCheck(.challenge, passed: parsed.challenge == challenge,
                    parsed.challenge == challenge ? "Matches the one issued." : "Does not match the one issued."),
            RPCheck(.origin, passed: parsed.origin == origin, "\(parsed.origin), expected \(origin)."),
        ]
    }

    private func authDataChecks(_ authData: AuthenticatorData) -> [RPCheck] {
        let expected = Data(SHA256.hash(data: Data(rpId.utf8)))
        return [
            RPCheck(.rpIdHash, passed: authData.rpIdHash == expected,
                    authData.rpIdHash == expected ? "SHA-256(\(rpId))." : "Not the hash of \(rpId)."),
            RPCheck(.userPresent, passed: authData.flags.contains(.userPresent), "Flags \(authData.flags)."),
            RPCheck(.userVerified, passed: authData.flags.contains(.userVerified), "Flags \(authData.flags)."),
        ]
    }

    private func signatureCheck(_ response: GetAssertionResponse, clientDataJSON: Data, stored: KnownCredential?) -> RPCheck {
        guard let stored, let key = try? ES256PublicKey(cose: stored.publicKeyCOSE) else {
            return RPCheck(.signature, passed: false, "No usable stored key.")
        }
        guard let signature = try? P256.Signing.ECDSASignature(derRepresentation: response.signature) else {
            return RPCheck(.signature, passed: false, "Not a DER ECDSA signature.")
        }
        let message = response.authenticatorData + Data(SHA256.hash(data: clientDataJSON))
        let valid = key.key.isValidSignature(signature, for: message)
        return RPCheck(.signature, passed: valid, valid ? "Valid over authData ‖ clientDataHash." : "Does not verify.")
    }

    private func signCountCheck(new: UInt32, stored: UInt32?) -> RPCheck {
        guard let stored, stored != 0, new != 0 else { return RPCheck(.signCount, passed: true, "Counter not used (\(new)).") }
        return RPCheck(.signCount, passed: new > stored, new > stored ? "\(stored) → \(new)." : "\(new) is not greater than \(stored).")
    }
}
