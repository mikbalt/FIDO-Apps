import Foundation

/// Something in WebAuthn data (options, clientData, authenticatorData, COSE key) could not be used.
public enum WebAuthnError: Error, Equatable, Sendable {
    case invalidBase64URL
    case truncatedAuthenticatorData
    case trailingBytes(count: Int)
    case invalidCBOR(String)
    case invalidCOSEKey(String)
    case invalidClientData(String)
    case invalidResponse(label: String, reason: String)
}

extension WebAuthnError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidBase64URL: "Not valid base64url."
        case .truncatedAuthenticatorData: "authenticatorData is too short."
        case let .trailingBytes(count): "authenticatorData has \(count) unexpected trailing bytes."
        case let .invalidCBOR(reason): "Invalid CBOR: \(reason)"
        case let .invalidCOSEKey(reason): "Invalid COSE key: \(reason)"
        case let .invalidClientData(reason): "Invalid clientDataJSON: \(reason)"
        case let .invalidResponse(label, reason): "\(label): \(reason)"
        }
    }
}
