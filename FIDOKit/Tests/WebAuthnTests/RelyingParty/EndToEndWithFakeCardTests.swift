import Foundation
import Testing
@testable import WebAuthn

@Suite("Register then authenticate: RP and fake card together")
struct EndToEndWithFakeCardTests {
    @Test("All checks pass for both ceremonies, the counter goes up, and a reset breaks the login")
    func roundTrip() async throws {
        let session = try await CardSession()
        let rp = LocalRelyingParty()

        // Register
        let creation = rp.beginRegistration(username: "nusa-042")
        let createData = ClientData(kind: .create, challenge: creation.challenge, origin: rp.origin)
        let made = try await session.client.makeCredential(
            options: creation, clientDataHash: createData.hash, pinUvAuthToken: try await session.token(.makeCredential))
        let registered = rp.verifyRegistration(options: creation, clientDataJSON: createData.json, response: made, existingCredentialIds: [])
        #expect(registered.passed, "\(registered.checks.filter { !$0.passed })")
        let saved = try #require(registered.credential)

        // Authenticate
        let request = rp.beginAuthentication(credentialId: saved.credentialId)
        let getData = ClientData(kind: .get, challenge: request.challenge, origin: rp.origin)
        let asserted = try await session.client.getAssertion(
            options: request, clientDataHash: getData.hash, pinUvAuthToken: try await session.token(.getAssertion))
        let known = KnownCredential(credentialId: saved.credentialId, publicKeyCOSE: saved.publicKeyCOSE, signCount: saved.signCount)
        let login = rp.verifyAuthentication(options: request, clientDataJSON: getData.json, response: asserted, stored: known)
        #expect(login.passed, "\(login.checks.filter { !$0.passed })")
        #expect(login.newSignCount == 1)

        // Same response replayed against the updated counter: not greater, so it fails.
        let updated = KnownCredential(credentialId: saved.credentialId, publicKeyCOSE: saved.publicKeyCOSE, signCount: 1)
        let replay = rp.verifyAuthentication(options: request, clientDataJSON: getData.json, response: asserted, stored: updated)
        #expect(!replay.passed)
    }
}
