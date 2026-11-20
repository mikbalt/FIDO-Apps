import CryptoKit
import Foundation

/// Where PIN protocol 2 gets its randomness: the ephemeral key-agreement key and the AES IVs.
/// Injectable so tests are deterministic.
public protocol PinUvAuthRandomness: Sendable {
    func ephemeralKey() -> P256.KeyAgreement.PrivateKey
    /// 16 random bytes for an AES-CBC IV.
    func iv() -> Data
}

/// The system CSPRNG, through CryptoKit.
public struct SystemPinUvAuthRandomness: PinUvAuthRandomness {
    public init() {}

    public func ephemeralKey() -> P256.KeyAgreement.PrivateKey {
        P256.KeyAgreement.PrivateKey()
    }

    public func iv() -> Data {
        SymmetricKey(size: .init(bitCount: 128)).withUnsafeBytes { Data($0) }
    }
}
