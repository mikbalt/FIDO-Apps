import CTAP
import Foundation
import PinUvAuth

extension CTAPClient {
    /// authenticatorMakeCredential (`0x01`) for the creation options, with a PIN token that holds the `mc`
    /// permission for the rpId (get it with `ClientPIN.pinUvAuthToken`).
    ///
    /// `pinUvAuthParam = authenticate(token, clientDataHash)`, protocol 2. `options` is sent only when the
    /// credential must be discoverable (`{"rk": true}`); `up: false` is never sent, and `uv` is never sent
    /// together with `pinUvAuthParam`.
    ///
    /// The request carries no PIN and no token, only a MAC of public data, so the exchange is not `sensitive`.
    public func makeCredential(
        options: CreationOptions, clientDataHash: Data, pinUvAuthToken: Data
    ) async throws -> MakeCredentialResponse {
        var parameters: [CBORMapEntry] = [
            CBORMapEntry(key: 0x01, value: .bytes(clientDataHash)),
            CBORMapEntry(key: 0x02, value: ["id": .text(options.rp.id), "name": .text(options.rp.name)]),
            CBORMapEntry(key: 0x03, value: [
                "id": .bytes(options.user.id), "name": .text(options.user.name), "displayName": .text(options.user.displayName),
            ]),
            CBORMapEntry(key: 0x04, value: .array(options.pubKeyCredParams.map {
                ["alg": CBORValue($0.alg), "type": .text($0.type)]
            })),
        ]
        if options.requiresResidentKey {
            parameters.append(CBORMapEntry(key: 0x07, value: ["rk": true]))
        }
        parameters.append(CBORMapEntry(key: 0x08, value: .bytes(PinProtocolTwo.authenticate(token: pinUvAuthToken, clientDataHash))))
        parameters.append(CBORMapEntry(key: 0x09, value: CBORValue(PinProtocolTwo.version)))

        let body = try await send(.makeCredential, parameters: .map(parameters), label: "MAKE_CREDENTIAL")
        return try MakeCredentialResponse(decoding: body)
    }
}
