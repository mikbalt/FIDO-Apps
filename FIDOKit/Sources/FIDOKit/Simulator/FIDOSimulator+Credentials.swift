import Foundation

extension FIDOSimulator {
    /// `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_TOKEN` → `MAKE_CREDENTIAL`,
    /// then the session closes, then the RP checks and the store.
    ///
    /// Steps: `waitingForCard` → `cardDetected` → `pinVerified` → `executing("Creating credential")` →
    /// `executing("Verify and save")` → `completed`. A wrong PIN or a card refusal ends the session
    /// `completed` with a failed outcome and no value.
    public func register(
        _ request: RegistrationRequest, progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<RegistrationOutcome> {
        let rp = configuration.relyingParty
        let store = configuration.credentialStore
        return await run(.register, cardLabel: request.cardLabel, progress: progress, validate: {
            _ = try CardPIN(request.pin)
        }, body: { (context: ScenarioContext) -> RawRegistration in
            try await context.selectFIDO()
            let info = try await context.getInfo()
            try Self.requirePinProtocol2(info)
            let token = try await Self.pinToken(context, info: info, pin: request.pin, permissions: .makeCredential, rpId: rp.rpId)
            context.progress(.pinVerified)

            let options = rp.beginRegistration(username: request.username, residentKey: request.residentKey)
            let clientData = ClientData(kind: .create, challenge: options.challenge, origin: rp.origin)
            context.progress(.executing("Creating credential"))
            let response = try await context.client.makeCredential(
                options: options, clientDataHash: clientData.hash, pinUvAuthToken: token)
            return RawRegistration(options: options, clientData: clientData, response: response)
        }, finalize: { (raw: RawRegistration, progress) in
            progress(.executing("Verify and save"))
            return Self.verifyAndSave(raw, request: request, rp: rp, store: store)
        })
    }

    /// `SELECT_FIDO` → `GET_INFO` → `CLIENT_PIN_KEY_AGREEMENT` → `CLIENT_PIN_TOKEN` → `GET_ASSERTION`,
    /// then the session closes, then the RP checks and the store update.
    public func authenticate(
        _ request: AuthenticationRequest, progress: @escaping @Sendable (ScenarioStep) -> Void
    ) async -> ScenarioResult<AuthenticationOutcome> {
        let rp = configuration.relyingParty
        let store = configuration.credentialStore
        return await run(.authenticate, cardLabel: request.cardLabel, progress: progress, validate: {
            _ = try CardPIN(request.pin)
        }, body: { (context: ScenarioContext) -> RawAuthentication in
            try await context.selectFIDO()
            let info = try await context.getInfo()
            try Self.requirePinProtocol2(info)
            let token = try await Self.pinToken(context, info: info, pin: request.pin, permissions: .getAssertion, rpId: rp.rpId)
            context.progress(.pinVerified)

            let options = rp.beginAuthentication(credentialId: request.credential.credentialId)
            let clientData = ClientData(kind: .get, challenge: options.challenge, origin: rp.origin)
            context.progress(.executing("Authenticating"))
            let response = try await context.client.getAssertion(
                options: options, clientDataHash: clientData.hash, pinUvAuthToken: token)
            return RawAuthentication(options: options, clientData: clientData, response: response)
        }, finalize: { (raw: RawAuthentication, progress) in
            progress(.executing("Verify and save"))
            return Self.verifyAndUpdate(raw, request: request, rp: rp, store: store)
        })
    }

    // MARK: - Private

    private struct RawRegistration: Sendable {
        let options: CreationOptions
        let clientData: ClientData
        let response: MakeCredentialResponse
    }

    private struct RawAuthentication: Sendable {
        let options: RequestOptions
        let clientData: ClientData
        let response: GetAssertionResponse
    }

    /// `CLIENT_PIN_KEY_AGREEMENT` then `CLIENT_PIN_TOKEN` with the given permission. A CTAP 2.0 card without
    /// the `pinUvAuthToken` option gets the plain getPinToken.
    private static func pinToken(
        _ context: ScenarioContext, info: AuthenticatorInfo, pin: String, permissions: PinUvAuthPermissions, rpId: String
    ) async throws -> Data {
        let pin = try CardPIN(pin)
        let agreement = try await context.execute("CLIENT_PIN_KEY_AGREEMENT") { try await context.clientPIN.keyAgreement() }
        return try await context.execute("CLIENT_PIN_TOKEN") {
            if info.options.pinUvAuthToken == true {
                try await context.clientPIN.pinUvAuthToken(pin: pin, permissions: permissions, rpId: rpId, using: agreement)
            } else {
                try await context.clientPIN.pinToken(pin: pin, using: agreement)
            }
        }
    }

    private static func verifyAndSave(
        _ raw: RawRegistration, request: RegistrationRequest, rp: LocalRelyingParty, store: CredentialStore?
    ) -> RegistrationOutcome {
        let verification = rp.verifyRegistration(
            options: raw.options, clientDataJSON: raw.clientData.json, response: raw.response,
            existingCredentialIds: Set(store?.all().map(\.credentialId) ?? []))
        let result = try? RegistrationResultJSON(
            credentialId: verification.credential?.credentialId ?? Data(), clientDataJSON: raw.clientData.json, response: raw.response)
        guard let verified = verification.credential else {
            return RegistrationOutcome(result: nil, checks: verification.checks, credential: nil, saveError: nil)
        }
        let credential = StoredCredential(
            credentialId: verified.credentialId, rpId: rp.rpId, userHandle: raw.options.user.id, username: request.username,
            cardLabel: request.cardLabel, publicKeyCOSE: verified.publicKeyCOSE, signCount: verified.signCount,
            discoverable: request.residentKey, attestationFormat: verified.attestationFormat)
        var saveError: String?
        do {
            try store?.save(credential, details: RegistrationDetails(aaguid: verified.aaguid, flags: verified.flags.rawValue))
        } catch {
            saveError = error.localizedDescription
        }
        return RegistrationOutcome(result: result, checks: verification.checks, credential: credential, saveError: saveError)
    }

    private static func verifyAndUpdate(
        _ raw: RawAuthentication, request: AuthenticationRequest, rp: LocalRelyingParty, store: CredentialStore?
    ) -> AuthenticationOutcome {
        let stored = request.credential
        let verification = rp.verifyAuthentication(
            options: raw.options, clientDataJSON: raw.clientData.json, response: raw.response,
            stored: KnownCredential(
                credentialId: stored.credentialId, publicKeyCOSE: stored.publicKeyCOSE, signCount: stored.signCount,
                invalidated: stored.invalidated))
        let result = AuthenticationResultJSON(
            credentialId: stored.credentialId, clientDataJSON: raw.clientData.json, response: raw.response)
        guard let newSignCount = verification.newSignCount else {
            return AuthenticationOutcome(result: result, checks: verification.checks, credential: stored, saveError: nil)
        }
        var updated = stored
        updated.signCount = newSignCount
        updated.lastUsedAt = .now
        var saveError: String?
        do {
            try store?.save(updated)
        } catch {
            saveError = error.localizedDescription
        }
        return AuthenticationOutcome(result: result, checks: verification.checks, credential: updated, saveError: saveError)
    }
}
