import CTAP
import Foundation
import PinUvAuth

extension CTAPClient {
    /// authenticatorGetAssertion (`0x02`) for the request options, with a PIN token that holds the `ga`
    /// permission for the rpId.
    ///
    /// `allowList` comes from `options.allowCredentials`. No `rk` and no `up` are sent (`up` stays at its
    /// default). Not `sensitive`, for the same reason as MakeCredential.
    public func getAssertion(
        options: RequestOptions, clientDataHash: Data, pinUvAuthToken: Data
    ) async throws -> GetAssertionResponse {
        var parameters: [CBORMapEntry] = [
            CBORMapEntry(key: 0x01, value: .text(options.rpId)),
            CBORMapEntry(key: 0x02, value: .bytes(clientDataHash)),
        ]
        if !options.allowCredentials.isEmpty {
            parameters.append(CBORMapEntry(key: 0x03, value: .array(options.allowCredentials.map {
                ["id": .bytes($0.id), "type": .text($0.type)]
            })))
        }
        parameters.append(CBORMapEntry(key: 0x06, value: .bytes(PinProtocolTwo.authenticate(token: pinUvAuthToken, clientDataHash))))
        parameters.append(CBORMapEntry(key: 0x07, value: CBORValue(PinProtocolTwo.version)))

        let body = try await send(.getAssertion, parameters: .map(parameters), label: "GET_ASSERTION")
        return try GetAssertionResponse(decoding: body)
    }
}
