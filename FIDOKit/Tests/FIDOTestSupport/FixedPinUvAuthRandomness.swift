import CryptoKit
import Foundation
import PinUvAuth

/// Deterministic randomness for tests: a fixed ephemeral key and IV.
public struct FixedPinUvAuthRandomness: PinUvAuthRandomness {
    public let key: P256.KeyAgreement.PrivateKey
    public let fixedIV: Data

    /// Any 32-byte value below the curve order is a valid P-256 private key, e.g. 32 × `0x11`.
    public init(keySeed: UInt8 = 0x11, iv: Data = Data(0..<16)) throws {
        key = try P256.KeyAgreement.PrivateKey(rawRepresentation: Data(repeating: keySeed, count: 32))
        fixedIV = iv
    }

    public func ephemeralKey() -> P256.KeyAgreement.PrivateKey { key }
    public func iv() -> Data { fixedIV }
}
