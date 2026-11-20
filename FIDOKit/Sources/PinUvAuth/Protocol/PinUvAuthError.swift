import CardCore
import Foundation

public enum PinUvAuthError: Error, Equatable, Sendable {
    /// The card's key-agreement key is not a P-256 COSE EC2 key.
    case invalidPeerKey(String)
    /// AES-CBC without padding needs a multiple of 16 bytes.
    case notBlockAligned(count: Int)
    /// A ciphertext shorter than IV + one block.
    case ciphertextTooShort(count: Int)
    /// CommonCrypto returned an error status.
    case cryptoFailed(status: Int32)
}

extension PinUvAuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidPeerKey(reason): "The card's key-agreement key is invalid: \(reason)."
        case let .notBlockAligned(count): "\(count) bytes is not a multiple of the AES block size."
        case let .ciphertextTooShort(count): "A \(count)-byte ciphertext is too short."
        case let .cryptoFailed(status): "AES-CBC failed (CommonCrypto status \(status))."
        }
    }
}

extension PinUvAuthError: TraceErrorConvertible {
    public var traceError: TraceError {
        let (code, name): (String, String) = switch self {
        case .invalidPeerKey: ("invalidPeerKey", "PIN_PROTOCOL_INVALID_PEER_KEY")
        case .notBlockAligned: ("notBlockAligned", "PIN_PROTOCOL_NOT_BLOCK_ALIGNED")
        case .ciphertextTooShort: ("ciphertextTooShort", "PIN_PROTOCOL_CIPHERTEXT_TOO_SHORT")
        case .cryptoFailed: ("cryptoFailed", "PIN_PROTOCOL_CRYPTO_FAILED")
        }
        return TraceError(domain: .validation, code: code, name: name, message: errorDescription ?? name)
    }
}
