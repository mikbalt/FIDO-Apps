import CardCore
import CTAP
import FIDOTestSupport
import Foundation
import PinUvAuth
import Testing

@Suite("authenticatorClientPIN against a fake card")
struct ClientPINTests {
    private func clientPIN(_ card: FakeAuthenticator) async throws -> ClientPIN {
        let connection = try await card.open(prompt: "")
        let recorder = TraceRecorder(
            metadata: TraceMetadata(transport: .mock, cardLabel: "Fake", options: TraceOptions()), connection: connection
        )
        return ClientPIN(client: CTAPClient(channel: ISO7816Channel(transport: card, recorder: recorder)))
    }

    @Test("setPIN then changePIN; the card verifies every pinUvAuthParam and PIN hash")
    func setAndChange() async throws {
        let card = FakeAuthenticator()
        let pin = try await clientPIN(card)

        try await pin.setPIN(try CardPIN("1234"), using: try await pin.keyAgreement())
        #expect(await card.pin == Data("1234".utf8))

        try await pin.changePIN(current: try CardPIN("1234"), new: try CardPIN("5678"), using: try await pin.keyAgreement())
        #expect(await card.pin == Data("5678".utf8))
        #expect(try await pin.getPINRetries() == 8)
    }

    @Test("A wrong current PIN gives 0x31 with the remaining retries; retries go down by one")
    func wrongPIN() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let pin = try await clientPIN(card)
        do {
            try await pin.changePIN(current: try CardPIN("0000"), new: try CardPIN("5678"), using: try await pin.keyAgreement())
            Issue.record("Expected PIN_INVALID")
        } catch let error as CTAPError {
            #expect(error.code == 0x31)
            #expect(error.name == "CTAP2_ERR_PIN_INVALID")
            #expect(error.detail == "7 retries left.")
            #expect(error.localizedDescription.hasSuffix("7 retries left."))
        }
        #expect(await card.retries == 7)
        #expect(await card.pin == Data("1234".utf8))
    }

    @Test("PIN_AUTH_BLOCKED and PIN_NOT_SET get the brief's messages")
    func errorMessages() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let pin = try await clientPIN(card)
        for _ in 0..<3 {
            _ = try? await pin.changePIN(current: try CardPIN("0000"), new: try CardPIN("5678"), using: try await pin.keyAgreement())
        }
        await #expect(throws: CTAPError(code: 0x34, detail: "Too many wrong PINs in a row: remove the card and tap again.")) {
            try await pin.changePIN(current: try CardPIN("0000"), new: try CardPIN("5678"), using: try await pin.keyAgreement())
        }

        let blank = try await clientPIN(FakeAuthenticator())
        await #expect(throws: CTAPError(code: 0x35, detail: "Use Set PIN first.")) {
            try await blank.changePIN(current: try CardPIN("1234"), new: try CardPIN("5678"), using: try await blank.keyAgreement())
        }
    }

    @Test("setPIN, changePIN and token subcommands are sensitive; retries and key agreement are not")
    func sensitiveFlags() async throws {
        let card = FakeAuthenticator()
        let pin = try await clientPIN(card)
        _ = try await pin.getPINRetries()
        try await pin.setPIN(try CardPIN("1234"), using: try await pin.keyAgreement())
        _ = try await pin.pinUvAuthToken(pin: try CardPIN("1234"), permissions: .makeCredential, rpId: "fidosims.local",
                                         using: try await pin.keyAgreement())
        let exchanges = await pin.client.channel.recorder.trace.exchanges
        let flags = Dictionary(exchanges.map { ($0.label, $0.sensitive) }, uniquingKeysWith: { $0 || $1 })
        #expect(flags == [
            "CLIENT_PIN_RETRIES": false, "CLIENT_PIN_KEY_AGREEMENT": false,
            "CLIENT_PIN_SET": true, "CLIENT_PIN_TOKEN": true,
        ])
    }

    @Test("The token is decrypted from response key 0x02")
    func token() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let pin = try await clientPIN(card)
        let token = try await pin.pinUvAuthToken(
            pin: try CardPIN("1234"), permissions: [.makeCredential, .getAssertion], rpId: nil, using: try await pin.keyAgreement()
        )
        #expect(token == Data(repeating: 0x7E, count: 32))
        let legacy = try await pin.pinToken(pin: try CardPIN("1234"), using: try await pin.keyAgreement())
        #expect(legacy == token)
    }
}
