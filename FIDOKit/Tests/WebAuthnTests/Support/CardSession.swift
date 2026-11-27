import CardCore
import CTAP
import FIDOTestSupport
import Foundation
import PinUvAuth
@testable import WebAuthn

/// A CTAP client over a `FakeAuthenticator`, with a recorder so tests can look at the trace.
struct CardSession {
    let card: FakeAuthenticator
    let client: CTAPClient
    let clientPIN: ClientPIN
    let recorder: TraceRecorder

    static let rpId = "fidosims.example"
    static let origin = "https://fidosims.example"

    init(pin: String? = "1234") async throws {
        card = FakeAuthenticator(pin: pin)
        let connection = try await card.open(prompt: "")
        recorder = TraceRecorder(
            metadata: TraceMetadata(transport: .mock, cardLabel: "Fake", options: TraceOptions()), connection: connection
        )
        client = CTAPClient(channel: ISO7816Channel(transport: card, recorder: recorder))
        clientPIN = ClientPIN(client: client)
    }

    func token(_ permissions: PinUvAuthPermissions, pin: String = "1234", rpId: String? = rpId) async throws -> Data {
        try await clientPIN.pinUvAuthToken(
            pin: try CardPIN(pin), permissions: permissions, rpId: rpId, using: try await clientPIN.keyAgreement())
    }

    func creationOptions(rk: Bool = false, challenge: Data = Data(repeating: 7, count: 32)) -> CreationOptions {
        CreationOptions(
            rp: .init(id: Self.rpId, name: "FIDOSims"),
            user: .init(id: Data(repeating: 9, count: 16), name: "nusa-042", displayName: "nusa-042"),
            challenge: challenge,
            authenticatorSelection: .init(residentKey: rk ? "required" : "discouraged", userVerification: "required")
        )
    }

    /// Registers a credential and returns what the RP tests need.
    func register(rk: Bool = false) async throws -> (options: CreationOptions, clientData: ClientData, response: MakeCredentialResponse) {
        let options = creationOptions(rk: rk)
        let clientData = ClientData(kind: .create, challenge: options.challenge, origin: Self.origin)
        let response = try await client.makeCredential(
            options: options, clientDataHash: clientData.hash, pinUvAuthToken: try await token(.makeCredential))
        return (options, clientData, response)
    }
}
