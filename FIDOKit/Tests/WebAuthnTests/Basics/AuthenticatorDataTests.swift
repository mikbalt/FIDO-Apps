import CTAP
import CryptoKit
import Foundation
import Testing
@testable import WebAuthn

@Suite("authenticatorData parser and COSE key")
struct AuthenticatorDataTests {
    @Test("Flags 0x41, 0x45 and 0x05 decode")
    func flags() throws {
        let key = P256.Signing.PrivateKey().publicKey
        let id = Data(repeating: 1, count: 16)
        let none = try AuthenticatorData(parsing: TestAuthData.build(flags: 0x05, signCount: 1))
        #expect(none.flags == [.userPresent, .userVerified])
        let upOnly = try AuthenticatorData(parsing: TestAuthData.build(flags: 0x41, credentialId: id, key: key))
        #expect(upOnly.flags == [.userPresent, .attestedCredentialData])
        #expect(!upOnly.flags.contains(.userVerified))
        let full = try AuthenticatorData(parsing: TestAuthData.build(flags: 0x45, credentialId: id, key: key))
        #expect(full.flags == [.userPresent, .userVerified, .attestedCredentialData])
        #expect(full.flags.description == "0x45")
    }

    @Test("Without attested data: rpIdHash, flags, signCount (big endian)")
    func withoutAttested() throws {
        let raw = TestAuthData.build(flags: 0x05, signCount: 0x0102_0304)
        let data = try AuthenticatorData(parsing: raw)
        #expect(data.rpIdHash == Data(SHA256.hash(data: Data("fidosims.example".utf8))))
        #expect(data.signCount == 0x0102_0304)
        #expect(data.attestedCredentialData == nil)
        #expect(data.extensions == nil)
        #expect(data.raw == raw)
    }

    @Test("With attested data: AAGUID, credential ID, COSE key bytes and the P-256 key")
    func withAttested() throws {
        let key = P256.Signing.PrivateKey().publicKey
        let id = Data((0..<32).map(UInt8.init))
        let aaguid = Data((100..<116).map(UInt8.init))
        let data = try AuthenticatorData(parsing: TestAuthData.build(flags: 0x45, signCount: 7, credentialId: id, key: key, aaguid: aaguid))
        let attested = try #require(data.attestedCredentialData)
        #expect(attested.aaguid == aaguid)
        #expect(attested.credentialId == id)
        #expect(attested.publicKeyCOSE == TestAuthData.cose(key))
        #expect(try attested.publicKey.get().key.x963Representation == key.x963Representation)
        #expect(try attested.publicKey.get().cose == TestAuthData.cose(key))
    }

    @Test("Extensions after the key are found with the bytes consumed")
    func extensions() throws {
        let key = P256.Signing.PrivateKey().publicKey
        let ext = Data([0xA1, 0x61, 0x61, 0x01])  // {"a": 1}
        let data = try AuthenticatorData(
            parsing: TestAuthData.build(flags: 0xC5, credentialId: Data([1, 2]), key: key, extensions: ext))
        #expect(data.extensions == ext)
        #expect(data.attestedCredentialData?.credentialId == Data([1, 2]))
    }

    @Test("Truncated and trailing bytes are errors")
    func malformed() {
        #expect(throws: WebAuthnError.truncatedAuthenticatorData) { try AuthenticatorData(parsing: Data(count: 36)) }
        let key = P256.Signing.PrivateKey().publicKey
        let good = TestAuthData.build(flags: 0x45, credentialId: Data([1, 2, 3]), key: key)
        #expect(throws: WebAuthnError.truncatedAuthenticatorData) {
            try AuthenticatorData(parsing: good.prefix(40))
        }
        #expect(throws: WebAuthnError.self) { try AuthenticatorData(parsing: good.prefix(good.count - 5)) }
        #expect(throws: WebAuthnError.trailingBytes(count: 1)) { try AuthenticatorData(parsing: good + [0]) }
        #expect(throws: WebAuthnError.trailingBytes(count: 1)) {
            try AuthenticatorData(parsing: TestAuthData.build(flags: 0x05) + [0])
        }
    }

    @Test("A COSE key that is not ES256 parses as authData but is flagged")
    func notES256() throws {
        var raw = TestAuthData.build(flags: 0x45, credentialId: Data([1]), key: P256.Signing.PrivateKey().publicKey)
        // Change alg -7 (0x26) to -8 (0x27) in the COSE key.
        let index = try #require(raw.lastIndex(of: 0x26))
        raw[index] = 0x27
        let data = try AuthenticatorData(parsing: raw)
        #expect(throws: WebAuthnError.self) { try data.attestedCredentialData?.publicKey.get() }
    }

    @Test("COSE key validation: kty, curve, coordinates, point on curve")
    func coseValidation() {
        let good = P256.Signing.PrivateKey().publicKey
        #expect(throws: Never.self) { try ES256PublicKey(cose: TestAuthData.cose(good)) }
        #expect(throws: WebAuthnError.self) { try ES256PublicKey(cose: Data([0x01])) }
        #expect(throws: WebAuthnError.self) { try ES256PublicKey(cose: Data([0xA0])) }
        // x = y = 0 is not on the curve.
        let off = try! CBOREncoder.encode(([
            1: 2, 3: -7, CBORValue(-1): 1, CBORValue(-2): .bytes(Data(count: 32)), CBORValue(-3): .bytes(Data(count: 32)),
        ] as CBORValue))
        #expect(throws: WebAuthnError.invalidCOSEKey("The point is not on P-256.")) { try ES256PublicKey(cose: off) }
    }
}
