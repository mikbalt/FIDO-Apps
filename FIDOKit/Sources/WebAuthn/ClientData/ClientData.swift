import CryptoKit
import Foundation

/// The clientDataJSON of a ceremony, serialized exactly as WebAuthn defines it, and its SHA-256.
///
/// `{"type":"webauthn.create","challenge":"<b64url>","origin":"https://…","crossOrigin":false}`: that key
/// order, no whitespace. The bytes are built by hand so the order is guaranteed.
public struct ClientData: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case create = "webauthn.create"
        case get = "webauthn.get"
    }

    public let json: Data
    /// `SHA-256(json)`, the `clientDataHash` sent to the card.
    public let hash: Data

    public init(kind: Kind, challenge: Data, origin: String) {
        let text = "{\"type\":\"\(kind.rawValue)\",\"challenge\":\"\(challenge.base64URLEncoded)\","
            + "\"origin\":\"\(Self.escape(origin))\",\"crossOrigin\":false}"
        json = Data(text.utf8)
        hash = Data(SHA256.hash(data: json))
    }

    /// JSON string escaping for the origin (`"` and `\` and control characters).
    private static func escape(_ string: String) -> String {
        var result = ""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result
    }
}
