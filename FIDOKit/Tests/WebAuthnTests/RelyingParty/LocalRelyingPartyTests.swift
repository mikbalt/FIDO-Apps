import CryptoKit
import Foundation
import Testing
@testable import WebAuthn

/// Test data is built here with a CryptoKit P-256 key; no card involved.
@Suite("Local RP checks")
struct LocalRelyingPartyTests {
    let rp = LocalRelyingParty()
    let key = P256.Signing.PrivateKey()
    let credentialId = Data(repeating: 0x42, count: 32)

    // MARK: Helpers

    private func name(_ verification: [RPCheck], _ name: RPCheck.Name) -> RPCheck? {
        verification.first { $0.name == name }
    }

    private func failed(_ checks: [RPCheck]) -> Set<RPCheck.Name> { Set(checks.filter { !$0.passed }.map(\.name)) }

    private func registration(
        flags: UInt8 = 0x45, rpId: String = "fidosims.example", challenge: Data? = nil, origin: String = LocalRelyingParty.defaultOrigin,
        kind: ClientData.Kind = .create, withAttested: Bool = true, tamperAuthData: Bool = false
    ) -> (options: CreationOptions, json: Data, response: MakeCredentialResponse) {
        let options = rp.beginRegistration(username: "nusa-042")
        let clientData = ClientData(kind: kind, challenge: challenge ?? options.challenge, origin: origin)
        var authData = TestAuthData.build(
            rpId: rpId, flags: flags, credentialId: withAttested ? credentialId : nil, key: withAttested ? key.publicKey : nil)
        if tamperAuthData { authData = Data(authData.dropLast(3)) }
        return (options, clientData.json, MakeCredentialResponse(format: "none", authenticatorData: authData, attestationStatement: []))
    }

    private func assertion(
        flags: UInt8 = 0x05, signCount: UInt32 = 5, challenge: Data? = nil, origin: String = LocalRelyingParty.defaultOrigin,
        signWith signer: P256.Signing.PrivateKey? = nil, tamper: Bool = false
    ) throws -> (options: RequestOptions, json: Data, response: GetAssertionResponse) {
        let options = rp.beginAuthentication(credentialId: credentialId)
        let clientData = ClientData(kind: .get, challenge: challenge ?? options.challenge, origin: origin)
        var authData = TestAuthData.build(flags: flags, signCount: signCount)
        let signature = try (signer ?? key).signature(for: authData + clientData.hash).derRepresentation
        if tamper { authData[33] ^= 0xFF }  // change signCount after signing
        return (options, clientData.json, GetAssertionResponse(credentialId: credentialId, authenticatorData: authData, signature: signature, userHandle: nil))
    }

    private func known(signCount: UInt32 = 1, invalidated: Bool = false) -> KnownCredential {
        KnownCredential(credentialId: credentialId, publicKeyCOSE: TestAuthData.cose(key.publicKey), signCount: signCount, invalidated: invalidated)
    }

    // MARK: Begin

    @Test("Begin: 32-byte challenge, 16-byte user ID, ES256, attestation none, UV required")
    func begin() {
        let options = rp.beginRegistration(username: "nusa-042")
        #expect(options.challenge.count == 32)
        #expect(options.user.id.count == 16)
        #expect(options.rp.id == "fidosims.example")
        #expect(options.pubKeyCredParams == [.es256])
        #expect(options.attestation == "none")
        #expect(options.authenticatorSelection?.userVerification == "required")
        #expect(!options.requiresResidentKey)
        #expect(rp.beginRegistration(username: "x", residentKey: true).requiresResidentKey)
        #expect(rp.beginRegistration(username: "x").challenge != options.challenge)
        let request = rp.beginAuthentication(credentialId: credentialId)
        #expect(request.challenge.count == 32)
        #expect(request.allowCredentials.map(\.id) == [credentialId])
    }

    // MARK: Registration

    @Test("A good registration passes every check and yields the credential to save")
    func registrationPasses() throws {
        let r = registration()
        let result = rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: [])
        #expect(result.passed)
        #expect(result.checks.count == 10)
        let credential = try #require(result.credential)
        #expect(credential.credentialId == credentialId)
        #expect(credential.publicKeyCOSE == TestAuthData.cose(key.publicKey))
        #expect(credential.flags.description == "0x45")
        #expect(credential.attestationFormat == "none")
        #expect(name(result.checks, .attestationFormat)?.detail == "none (recorded, not verified).")
    }

    @Test("Wrong challenge, origin and clientData type each fail only their check")
    func registrationClientData() {
        for (r, expected) in [
            (registration(challenge: Data(repeating: 1, count: 32)), RPCheck.Name.challenge),
            (registration(origin: "https://evil.example"), .origin),
            (registration(kind: .get), .clientDataType),
        ] {
            let result = rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: [])
            #expect(failed(result.checks) == [expected])
            #expect(result.credential == nil)
        }
    }

    @Test("Wrong rpIdHash, missing UP, missing UV and missing AT fail their checks")
    func registrationAuthData() {
        func run(_ r: (options: CreationOptions, json: Data, response: MakeCredentialResponse)) -> Set<RPCheck.Name> {
            failed(rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: []).checks)
        }
        #expect(run(registration(rpId: "other.example")) == [.rpIdHash])
        #expect(run(registration(flags: 0x44)) == [.userPresent])
        #expect(run(registration(flags: 0x41)) == [.userVerified])
        #expect(run(registration(flags: 0x05, withAttested: false)).isSuperset(of: [.attestedCredentialData, .publicKeyES256, .credentialNew]))
    }

    @Test("Tampered (truncated) authData fails to parse")
    func registrationTampered() {
        let r = registration(tamperAuthData: true)
        let result = rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: [])
        #expect(failed(result.checks).contains(.authenticatorDataParses))
        #expect(result.credential == nil)
    }

    @Test("A key that is not ES256 fails the key check")
    func registrationBadKey() throws {
        var r = registration()
        var data = r.response.authenticatorData
        data[try #require(data.lastIndex(of: 0x26))] = 0x27  // alg -8
        r.response = MakeCredentialResponse(format: "none", authenticatorData: data, attestationStatement: [])
        let result = rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: [])
        #expect(failed(result.checks) == [.publicKeyES256])
    }

    @Test("A credential ID that is already stored fails")
    func registrationDuplicate() {
        let r = registration()
        let result = rp.verifyRegistration(options: r.options, clientDataJSON: r.json, response: r.response, existingCredentialIds: [credentialId])
        #expect(failed(result.checks) == [.credentialNew])
        #expect(result.credential == nil)
    }

    @Test("Garbage clientDataJSON fails the three clientData checks")
    func registrationGarbageClientData() {
        let r = registration()
        let result = rp.verifyRegistration(options: r.options, clientDataJSON: Data("x".utf8), response: r.response, existingCredentialIds: [])
        #expect(failed(result.checks) == [.clientDataType, .challenge, .origin])
    }

    // MARK: Authentication

    @Test("A good authentication passes and returns the new counter")
    func authenticationPasses() throws {
        let a = try assertion()
        let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known())
        #expect(result.passed)
        #expect(result.newSignCount == 5)
        #expect(name(result.checks, .signCount)?.detail == "1 → 5.")
    }

    @Test("Wrong challenge and wrong origin fail; the signature still verifies over the hash we computed")
    func authenticationClientData() throws {
        let a = try assertion(challenge: Data(repeating: 1, count: 32))
        #expect(failed(rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known()).checks) == [.challenge])
        let b = try assertion(origin: "https://evil.example")
        #expect(failed(rp.verifyAuthentication(options: b.options, clientDataJSON: b.json, response: b.response, stored: known()).checks) == [.origin])
    }

    @Test("Tampered authData breaks the signature")
    func authenticationTampered() throws {
        let a = try assertion(tamper: true)
        let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known())
        #expect(failed(result.checks).contains(.signature))
        #expect(result.newSignCount == nil)
    }

    @Test("A signature by another key fails")
    func authenticationBadSignature() throws {
        let a = try assertion(signWith: P256.Signing.PrivateKey())
        let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known())
        #expect(failed(result.checks) == [.signature])
        #expect(name(result.checks, .signature)?.detail == "Does not verify.")
    }

    @Test("A signature that is not DER fails")
    func authenticationNotDER() throws {
        let a = try assertion()
        let response = GetAssertionResponse(credentialId: nil, authenticatorData: a.response.authenticatorData, signature: Data([1, 2]), userHandle: nil)
        let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: response, stored: known())
        #expect(failed(result.checks) == [.signature])
    }

    @Test("Missing UP or UV fails; the flags are not 0x05")
    func authenticationFlags() throws {
        let noUV = try assertion(flags: 0x01)
        #expect(failed(rp.verifyAuthentication(options: noUV.options, clientDataJSON: noUV.json, response: noUV.response, stored: known()).checks) == [.userVerified])
        let noUP = try assertion(flags: 0x04)
        #expect(failed(rp.verifyAuthentication(options: noUP.options, clientDataJSON: noUP.json, response: noUP.response, stored: known()).checks) == [.userPresent])
    }

    @Test("signCount: must increase when both are non-zero; zero on either side is 'counter not used'")
    func signCount() throws {
        for (stored, new, passes) in [(5, 5, false), (5, 4, false), (5, 6, true), (0, 3, true), (3, 0, true), (0, 0, true)] as [(UInt32, UInt32, Bool)] {
            let a = try assertion(signCount: new)
            let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known(signCount: stored))
            #expect(result.passed == passes, "stored \(stored), new \(new)")
            #expect(name(result.checks, .signCount)?.passed == passes)
        }
        let a = try assertion(signCount: 0)
        let result = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known(signCount: 3))
        #expect(name(result.checks, .signCount)?.detail == "Counter not used (0).")
    }

    @Test("An invalidated or unknown credential fails the first check")
    func authenticationUnknown() throws {
        let a = try assertion()
        let invalidated = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: known(invalidated: true))
        #expect(failed(invalidated.checks) == [.credentialKnown])
        let unknown = rp.verifyAuthentication(options: a.options, clientDataJSON: a.json, response: a.response, stored: nil)
        #expect(failed(unknown.checks).isSuperset(of: [.credentialKnown, .signature]))
    }
}
