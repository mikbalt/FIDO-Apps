import CardCore
import Foundation

/// Sends CTAP2 commands over an `ISO7816Channel`: `command byte ‖ CBOR(parameters)` in NFCCTAP_MSG.
///
/// P1 stays `00` (the channel's `getResponseSupported` is off by default): on NFC the tap already counts as
/// user presence.
public final class CTAPClient: Sendable {
    public let channel: ISO7816Channel

    public init(channel: ISO7816Channel) {
        self.channel = channel
    }

    /// Sends one CTAP command and returns the decoded response body, or `nil` if it is empty.
    ///
    /// The exchange that completes the command gets the status byte as its trace `ctapStatus`.
    ///
    /// - Throws: `CTAPError` for a non-zero status; `ChannelError.unexpectedStatus` when the SW is not
    ///   `9000` (e.g. `6D00` on a CTAP1-only card); `CTAPClientError` for a response it cannot use; and
    ///   transport errors.
    public func send(
        _ command: CTAPCommandCode,
        parameters: CBORValue?,
        label: String,
        sensitive: Bool = false
    ) async throws -> CBORValue? {
        var request = Data([command.rawValue])
        if let parameters {
            do {
                request.append(try CBOREncoder.encode(parameters))
            } catch let error as CBOREncodingError {
                throw CTAPClientError.invalidRequest(label: label, error)
            }
        }

        let response = try await channel.send(channel.nfcctapMsg(request), label: label, sensitive: sensitive)
        guard response.sw.isSuccess else { throw ChannelError.unexpectedStatus(response.sw) }
        guard let status = response.data.first else { throw CTAPClientError.missingStatus(label: label) }
        await channel.recorder.markCTAPStatus(status)
        guard status == CTAPStatusCode.ok else { throw CTAPError(code: status) }

        let body = response.data.dropFirst()
        guard !body.isEmpty else { return nil }
        do {
            return try CBORDecoder.decodeExactly(body).value
        } catch let error as CBORDecodingError {
            throw CTAPClientError.invalidCBOR(label: label, error)
        }
    }
}
