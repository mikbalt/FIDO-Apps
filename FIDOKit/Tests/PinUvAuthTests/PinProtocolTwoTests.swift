import CardCore
import CryptoKit
import CTAP
import FIDOTestSupport
import Foundation
import PinUvAuth
import Testing

@Suite("PIN protocol 2")
struct PinProtocolTwoTests {
    private func secret(aesKey: String = "603DEB1015CA71BE2B73AEF0857D77811F352C073B6108D72D9810A30914DFF4") throws -> PinUvAuthSharedSecret {
        PinUvAuthSharedSecret(hmacKey: SymmetricKey(data: Data(count: 32)), aesKey: SymmetricKey(data: try Hex.parse(aesKey)))
    }

    @Test("encrypt is AES-256-CBC, no padding, IV ‖ ciphertext (NIST SP 800-38A F.2.5)")
    func aesKnownAnswer() throws {
        let iv = try Hex.parse("000102030405060708090A0B0C0D0E0F")
        let pinProtocol = PinProtocolTwo(randomness: try FixedPinUvAuthRandomness(iv: iv))
        let ciphertext = try pinProtocol.encrypt(try secret(), try Hex.parse("6BC1BEE22E409F96E93D7E117393172A"))
        #expect(Hex.compact(ciphertext) == "000102030405060708090A0B0C0D0E0F" + "F58C4C04D6E5F1BA779EABFB5F7BFBD6")
    }

    @Test("Encrypt/decrypt round-trip with a random IV")
    func roundTrip() throws {
        let pinProtocol = PinProtocolTwo()
        let plaintext = Data((0..<64).map { UInt8($0) })
        let ciphertext = try pinProtocol.encrypt(try secret(), plaintext)
        #expect(ciphertext.count == 16 + 64)
        #expect(try pinProtocol.decrypt(try secret(), ciphertext) == plaintext)
        #expect(throws: PinUvAuthError.notBlockAligned(count: 15)) { try pinProtocol.encrypt(try secret(), Data(count: 15)) }
        #expect(throws: PinUvAuthError.ciphertextTooShort(count: 16)) { try pinProtocol.decrypt(try secret(), Data(count: 16)) }
    }

    @Test("The shared secret is two 32-byte HKDF calls, not one 64-byte call")
    func sharedSecretTwoCalls() throws {
        let z = Data((0..<32).map { UInt8($0 * 3) })
        let secret = PinUvAuthSharedSecret(z: z)
        func hkdf(_ info: String, _ count: Int) -> Data {
            HKDF<SHA256>.deriveKey(
                inputKeyMaterial: SymmetricKey(data: z), salt: Data(count: 32), info: Data(info.utf8), outputByteCount: count
            ).withUnsafeBytes { Data($0) }
        }
        let hmacKey = secret.hmacKey.withUnsafeBytes { Data($0) }
        let aesKey = secret.aesKey.withUnsafeBytes { Data($0) }
        #expect(hmacKey == hkdf("CTAP2 HMAC key", 32))
        #expect(aesKey == hkdf("CTAP2 AES key", 32))
        // One 64-byte call would make the AES half the second HMAC-info block instead.
        #expect(aesKey != hkdf("CTAP2 HMAC key", 64).suffix(32))
        #expect(!secret.description.contains(Hex.compact(hmacKey)))
    }

    @Test("authenticate is full 32-byte HMAC-SHA-256 (RFC 4231 test case 2)")
    func authenticate() throws {
        let mac = PinProtocolTwo.authenticate(token: Data("Jefe".utf8), Data("what do ya want for nothing?".utf8))
        #expect(mac.count == 32)
        #expect(Hex.compact(mac) == "5BDCC146BF60754E6A042426089575C75A003F089D2739839DEC58B964EC3843")
        #expect(PinProtocolTwo.authenticate(try secret(), Data("x".utf8)).count == 32)
    }

    @Test("Key agreement: both sides derive the same secret; the platform key is COSE EC2 with alg -25")
    func keyAgreement() throws {
        let randomness = try FixedPinUvAuthRandomness()
        let card = P256.KeyAgreement.PrivateKey()
        let agreement = try PinProtocolTwo(randomness: randomness).agree(with: PinProtocolTwo.coseKey(card.publicKey))

        #expect(agreement.platformKey.mapEntries?.map(\.key) == [1, 3, -1, -2, -3])
        #expect(agreement.platformKey[3] == -25)
        let platform = try PinProtocolTwo.publicKey(fromCOSE: agreement.platformKey)
        #expect(platform.x963Representation == randomness.key.publicKey.x963Representation)

        let cardZ = try card.sharedSecretFromKeyAgreement(with: platform).withUnsafeBytes { Data($0) }
        let cardSecret = PinUvAuthSharedSecret(z: cardZ)
        #expect(cardSecret.aesKey == agreement.sharedSecret.aesKey)
        #expect(cardSecret.hmacKey == agreement.sharedSecret.hmacKey)
    }

    @Test("Invalid card keys are refused")
    func invalidPeerKey() {
        #expect(throws: PinUvAuthError.self) { try PinProtocolTwo.publicKey(fromCOSE: [1: 1]) }
        #expect(throws: PinUvAuthError.self) {
            try PinProtocolTwo.publicKey(fromCOSE: [1: 2, -1: 1, -2: .bytes(Data(count: 32)), -3: .bytes(Data(count: 32))])
        }
    }
}
