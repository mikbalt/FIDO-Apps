import CardCore
import CommonCrypto
import CryptoKit
import CTAP
import Foundation

/// PIN/UV auth protocol 2 (CTAP 2.1 §6.5.7): key agreement, encrypt, decrypt and authenticate.
public struct PinProtocolTwo: Sendable {
    public static let version = 2

    private let randomness: any PinUvAuthRandomness

    public init(randomness: any PinUvAuthRandomness = SystemPinUvAuthRandomness()) {
        self.randomness = randomness
    }

    /// The result of key agreement with the card.
    public struct KeyAgreement: Sendable {
        /// The platform's ephemeral public key as COSE `{1: 2, 3: -25, -1: 1, -2: x, -3: y}`.
        public let platformKey: CBORValue
        public let sharedSecret: PinUvAuthSharedSecret
    }

    /// ECDH on P-256 with a fresh ephemeral key. Z is the x-coordinate of the shared point.
    ///
    /// - Parameter peerKey: The card's COSE key from getKeyAgreement.
    /// - Throws: `PinUvAuthError.invalidPeerKey`.
    public func agree(with peerKey: CBORValue) throws -> KeyAgreement {
        let peer = try Self.publicKey(fromCOSE: peerKey)
        let ephemeral = randomness.ephemeralKey()
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: peer)
        // CryptoKit's raw shared secret for P-256 is the 32-byte x-coordinate of the shared point.
        let z = shared.withUnsafeBytes { Data($0) }
        return KeyAgreement(
            platformKey: Self.coseKey(ephemeral.publicKey), sharedSecret: PinUvAuthSharedSecret(z: z)
        )
    }

    /// AES-256-CBC with the AES key, a random 16-byte IV and no padding. Returns `IV ‖ ciphertext`.
    public func encrypt(_ secret: PinUvAuthSharedSecret, _ plaintext: Data) throws -> Data {
        let iv = randomness.iv()
        return iv + (try Self.aesCBC(CCOperation(kCCEncrypt), key: secret.aesKey, iv: iv, data: plaintext))
    }

    /// The inverse of `encrypt`: splits off the IV and decrypts the rest.
    public func decrypt(_ secret: PinUvAuthSharedSecret, _ ciphertext: Data) throws -> Data {
        guard ciphertext.count >= 32 else { throw PinUvAuthError.ciphertextTooShort(count: ciphertext.count) }
        let iv = ciphertext.prefix(16)
        return try Self.aesCBC(CCOperation(kCCDecrypt), key: secret.aesKey, iv: Data(iv), data: Data(ciphertext.dropFirst(16)))
    }

    /// HMAC-SHA-256 with the shared secret's HMAC key, full 32 bytes.
    public static func authenticate(_ secret: PinUvAuthSharedSecret, _ message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: secret.hmacKey))
    }

    /// HMAC-SHA-256 with a pinUvAuthToken as the key, full 32 bytes.
    public static func authenticate(token: Data, _ message: Data) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: token)))
    }

    // MARK: COSE

    /// `{1: 2 (EC2), 3: -25 (ECDH-ES+HKDF-256), -1: 1 (P-256), -2: x, -3: y}`.
    public static func coseKey(_ key: P256.KeyAgreement.PublicKey) -> CBORValue {
        let point = key.x963Representation  // 04 ‖ x ‖ y
        return [
            1: 2, 3: -25, -1: 1,
            -2: .bytes(Data(point[1..<33])), -3: .bytes(Data(point[33..<65])),
        ]
    }

    public static func publicKey(fromCOSE key: CBORValue) throws -> P256.KeyAgreement.PublicKey {
        guard key.mapEntries != nil else { throw PinUvAuthError.invalidPeerKey("not a map") }
        guard key[1] == 2 else { throw PinUvAuthError.invalidPeerKey("kty is not EC2") }
        guard key[-1] == 1 else { throw PinUvAuthError.invalidPeerKey("crv is not P-256") }
        guard let x = key[-2]?.bytesValue, let y = key[-3]?.bytesValue, x.count == 32, y.count == 32 else {
            throw PinUvAuthError.invalidPeerKey("x and y must be 32 bytes")
        }
        do {
            return try P256.KeyAgreement.PublicKey(x963Representation: Data([0x04]) + x + y)
        } catch {
            throw PinUvAuthError.invalidPeerKey("not a point on P-256")
        }
    }

    // MARK: AES-CBC

    private static func aesCBC(_ operation: CCOperation, key: SymmetricKey, iv: Data, data: Data) throws -> Data {
        guard data.count % kCCBlockSizeAES128 == 0 else { throw PinUvAuthError.notBlockAligned(count: data.count) }
        var output = Data(count: data.count)
        var moved = 0
        let status = output.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in
                iv.withUnsafeBytes { ivBytes in
                    key.withUnsafeBytes { keyBytes in
                        // Options 0: CBC mode, no padding.
                        CCCrypt(
                            operation, CCAlgorithm(kCCAlgorithmAES), CCOptions(0),
                            keyBytes.baseAddress, keyBytes.count, ivBytes.baseAddress,
                            input.baseAddress, input.count, out.baseAddress, out.count, &moved
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw PinUvAuthError.cryptoFailed(status: status) }
        return output.prefix(moved)
    }
}
