import CardCore

extension CTAPClient {
    /// authenticatorGetInfo, labelled `GET_INFO`. Fills the trace's card metadata.
    public func getInfo() async throws -> AuthenticatorInfo {
        guard let body = try await send(.getInfo, parameters: nil, label: "GET_INFO") else {
            throw CTAPClientError.unexpectedResponse(label: "GET_INFO", reason: "Empty body.")
        }
        let info = try AuthenticatorInfo(cbor: body)
        await channel.recorder.setCardDetails(
            aaguid: info.aaguid, versions: info.versions, firmwareVersion: info.firmwareVersion
        )
        return info
    }
}
