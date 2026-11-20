import CryptoKit
import Foundation

/// The 64-byte PIN protocol 2 shared secret: an HMAC key and an AES key, 32 bytes each.
///
/// Never printed: `description` hides the bytes, so a stray log line cannot leak it.
public struct PinUvAuthSharedSecret: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    /// `HKDF-SHA-256(salt = 32 × 00, IKM = Z, info = "CTAP2 HMAC key", L = 32)`.
    public let hmacKey: SymmetricKey
    /// `HKDF-SHA-256(salt = 32 × 00, IKM = Z, info = "CTAP2 AES key", L = 32)`.
    public let aesKey: SymmetricKey

    public init(hmacKey: SymmetricKey, aesKey: SymmetricKey) {
        self.hmacKey = hmacKey
        self.aesKey = aesKey
    }

    /// Two separate 32-byte HKDF calls, not one 64-byte call (CTAP 2.1 §6.5.7).
    public init(z: Data) {
        let ikm = SymmetricKey(data: z)
        let salt = Data(count: 32)
        hmacKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm, salt: salt, info: Data("CTAP2 HMAC key".utf8), outputByteCount: 32
        )
        aesKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: ikm, salt: salt, info: Data("CTAP2 AES key".utf8), outputByteCount: 32
        )
    }

    public var description: String { "PinUvAuthSharedSecret(<redacted 64 bytes>)" }
    public var debugDescription: String { description }
}
