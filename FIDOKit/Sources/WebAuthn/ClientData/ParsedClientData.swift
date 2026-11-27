import Foundation

/// The fields of a received clientDataJSON that the RP checks.
public struct ParsedClientData: Sendable, Equatable {
    public let type: String
    public let challenge: Data
    public let origin: String

    private struct Raw: Decodable {
        let type: String
        let challenge: String
        let origin: String
    }

    public init(json: Data) throws {
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: json)
        } catch {
            throw WebAuthnError.invalidClientData("Not a clientData object.")
        }
        guard let challenge = Data(base64URLEncoded: raw.challenge) else {
            throw WebAuthnError.invalidClientData("The challenge is not base64url.")
        }
        type = raw.type
        self.challenge = challenge
        origin = raw.origin
    }
}
