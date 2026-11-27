import CryptoKit
import CTAP
import Foundation
import Testing
@testable import WebAuthn

@Suite("MakeCredential against a fake card")
struct MakeCredentialTests {
    @Test("Registers: flags 0x45, ES256 key, credential ID matches the card's")
    func registers() async throws {
        let session = try await CardSession()
        let (_, _, response) = try await session.register()
        let authData = try AuthenticatorData(parsing: response.authenticatorData)
        #expect(authData.flags == [.userPresent, .userVerified, .attestedCredentialData])
        let attested = try #require(authData.attestedCredentialData)
        let card = try #require(await session.card.credentials.first)
        #expect(attested.credentialId == card.id)
        #expect(try attested.publicKey.get().key.x963Representation == card.publicKey.x963Representation)
        #expect(authData.rpIdHash == Data(SHA256.hash(data: Data(CardSession.rpId.utf8))))
        #expect(response.format == "none")
    }

    @Test("The request has the brief's parameters and no options without rk")
    func requestShape() async throws {
        let session = try await CardSession()
        let (options, clientData, _) = try await session.register()
        let request = try #require(await session.card.requests.last(where: { $0.command == 0x01 })?.parameters)
        #expect(request[1]?.bytesValue == clientData.hash)
        #expect(request[2]?["id"]?.textValue == "fidosims.example")
        #expect(request[3]?["id"]?.bytesValue == options.user.id)
        #expect(request[3]?["name"]?.textValue == "nusa-042")
        #expect(request[4]?.arrayValue?.first?["alg"]?.intValue == -7)
        #expect(request[7] == nil)
        #expect(request[8]?.bytesValue?.count == 32)
        #expect(request[9]?.intValue == 2)
    }

    @Test("rk sends {rk: true} and nothing else; no up, no uv next to pinUvAuthParam")
    func residentKey() async throws {
        let session = try await CardSession()
        _ = try await session.register(rk: true)
        let request = try #require(await session.card.requests.last(where: { $0.command == 0x01 })?.parameters)
        #expect(request[7] == ["rk": true])
        #expect(await session.card.credentials.first?.discoverable == true)
    }

    @Test("The PIN token is requested with the mc permission and the rpId")
    func tokenGrant() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let grant = try #require(await session.card.tokenGrant)
        #expect(grant.permissions == 0x01)
        #expect(grant.rpId == "fidosims.example")
    }

    @Test("A token for another permission or rpId is refused by the card with PIN_AUTH_INVALID")
    func wrongToken() async throws {
        let session = try await CardSession()
        let options = session.creationOptions()
        let hash = ClientData(kind: .create, challenge: options.challenge, origin: CardSession.origin).hash
        let ga = try await session.token(.getAssertion)
        await #expect(throws: CTAPError(code: 0x33)) {
            try await session.client.makeCredential(options: options, clientDataHash: hash, pinUvAuthToken: ga)
        }
        let other = try await session.token(.makeCredential, rpId: "other.example")
        await #expect(throws: CTAPError(code: 0x33)) {
            try await session.client.makeCredential(options: options, clientDataHash: hash, pinUvAuthToken: other)
        }
    }

    @Test("The result JSON has the toJSON fields; attestationObject has fmt, attStmt, authData")
    func resultJSON() async throws {
        let session = try await CardSession()
        let (_, clientData, response) = try await session.register()
        let id = try #require(await session.card.credentials.first?.id)
        let result = try RegistrationResultJSON(credentialId: id, clientDataJSON: clientData.json, response: response)
        let json = try JSONSerialization.jsonObject(with: try WebAuthnJSON.encoder().encode(result)) as? [String: Any]
        #expect(json?["id"] as? String == id.base64URLEncoded)
        #expect(json?["rawId"] as? String == id.base64URLEncoded)
        #expect(json?["type"] as? String == "public-key")
        let inner = try #require(json?["response"] as? [String: Any])
        #expect(inner["transports"] as? [String] == ["nfc"])
        #expect(inner["publicKeyAlgorithm"] as? Int == -7)
        #expect(inner["clientDataJSON"] as? String == clientData.json.base64URLEncoded)
        #expect(inner["authenticatorData"] as? String == response.authenticatorData.base64URLEncoded)

        let object = try CBORDecoder.decodeExactly(try response.attestationObject()).value
        #expect(object["fmt"]?.textValue == "none")
        #expect(object["authData"]?.bytesValue == response.authenticatorData)
        #expect(object["attStmt"] != nil)
    }

    @Test("The trace labels the exchange MAKE_CREDENTIAL with its CTAP status")
    func traceLabel() async throws {
        let session = try await CardSession()
        _ = try await session.register()
        let trace = await session.recorder.trace
        let exchange = try #require(trace.exchanges.last(where: { $0.label == "MAKE_CREDENTIAL" }))
        #expect(exchange.ctapStatus == 0x00)
        #expect(exchange.sensitive == false)
    }
}
