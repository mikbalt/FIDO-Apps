import CryptoKit
import CTAP
import Foundation
import PinUvAuth
import Testing
@testable import WebAuthn

@Suite("GetAssertion against a fake card")
struct GetAssertionTests {
    private func assert(_ session: CardSession, credentialId: Data, challenge: Data = Data(repeating: 3, count: 32)) async throws
        -> (options: RequestOptions, clientData: ClientData, response: GetAssertionResponse) {
        let options = RequestOptions(
            rpId: CardSession.rpId, challenge: challenge, allowCredentials: [CredentialDescriptor(id: credentialId)])
        let clientData = ClientData(kind: .get, challenge: challenge, origin: CardSession.origin)
        let response = try await session.client.getAssertion(
            options: options, clientDataHash: clientData.hash, pinUvAuthToken: try await session.token(.getAssertion))
        return (options, clientData, response)
    }

    @Test("Authenticates: flags 0x05 and a signature that verifies with the registered key")
    func authenticates() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let credential = try #require(await session.card.credentials.first)
        let (_, clientData, response) = try await assert(session, credentialId: credential.id)

        let authData = try AuthenticatorData(parsing: response.authenticatorData)
        #expect(authData.flags == [.userPresent, .userVerified])
        #expect(authData.attestedCredentialData == nil)
        #expect(authData.signCount == 1)
        let signature = try P256.Signing.ECDSASignature(derRepresentation: response.signature)
        #expect(credential.publicKey.isValidSignature(signature, for: response.authenticatorData + clientData.hash))
        #expect(response.credentialId == credential.id)
    }

    @Test("The request has rpId, hash, allowList, pinUvAuthParam and protocol 2, and no rk, no options")
    func requestShape() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let id = try #require(await session.card.credentials.first?.id)
        let (_, clientData, _) = try await assert(session, credentialId: id)
        let request = try #require(await session.card.requests.last(where: { $0.command == 0x02 })?.parameters)
        #expect(request[1]?.textValue == "fidosims.example")
        #expect(request[2]?.bytesValue == clientData.hash)
        #expect(request[3]?.arrayValue?.first?["id"]?.bytesValue == id)
        #expect(request[3]?.arrayValue?.first?["type"]?.textValue == "public-key")
        #expect(request[5] == nil)
        #expect(request[6]?.bytesValue?.count == 32)
        #expect(request[7]?.intValue == 2)
        let grant = try #require(await session.card.tokenGrant)
        #expect(grant.permissions == 0x02)
        #expect(grant.rpId == "fidosims.example")
    }

    @Test("An unknown credential gives NO_CREDENTIALS (0x2E), as after a reset")
    func noCredentials() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let id = try #require(await session.card.credentials.first?.id)
        _ = try await session.client.send(.reset, parameters: nil, label: "RESET")
        // Reset removed the PIN; set it again so a token can be issued.
        let agreement = try await session.clientPIN.keyAgreement()
        try await session.clientPIN.setPIN(try CardPIN("1234"), using: agreement)
        await #expect(throws: CTAPError(code: 0x2E)) { _ = try await assert(session, credentialId: id) }
    }

    @Test("A card that keeps no counter answers signCount 0")
    func noCounter() async throws {
        let session = try await CardSession()
        await session.card.setCountsSignatures(false)
        _ = try await session.register()
        let id = try #require(await session.card.credentials.first?.id)
        let (_, _, response) = try await assert(session, credentialId: id)
        #expect(try AuthenticatorData(parsing: response.authenticatorData).signCount == 0)
    }

    @Test("The result JSON has id, rawId, type and the response fields; the user handle is omitted when absent")
    func resultJSON() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let id = try #require(await session.card.credentials.first?.id)
        let (_, clientData, response) = try await assert(session, credentialId: id)
        let result = AuthenticationResultJSON(credentialId: id, clientDataJSON: clientData.json, response: response)
        let json = try JSONSerialization.jsonObject(with: try WebAuthnJSON.encoder().encode(result)) as? [String: Any]
        #expect(json?["id"] as? String == id.base64URLEncoded)
        #expect(json?["type"] as? String == "public-key")
        let inner = try #require(json?["response"] as? [String: Any])
        #expect(inner["signature"] as? String == response.signature.base64URLEncoded)
        #expect(inner["authenticatorData"] as? String == response.authenticatorData.base64URLEncoded)
        #expect(inner["clientDataJSON"] as? String == clientData.json.base64URLEncoded)
        #expect(inner["userHandle"] == nil)
    }

    @Test("A response without a signature is rejected")
    func malformedResponse() {
        #expect(throws: WebAuthnError.self) { try GetAssertionResponse(decoding: [2: .bytes(Data(count: 37))]) }
        #expect(throws: WebAuthnError.self) { try MakeCredentialResponse(decoding: nil) }
    }
}
