import CryptoKit
import Foundation
import PinUvAuth
import Testing

@Suite("PIN validation")
struct CardPINTests {
    @Test("NFC normalization: composed and decomposed forms give the same bytes")
    func normalization() throws {
        let composed = try CardPIN("caf\u{E9}1")
        let decomposed = try CardPIN("cafe\u{301}1")
        #expect(composed == decomposed)
        #expect(composed.utf8 == Data("caf\u{E9}1".utf8))
    }

    @Test("At least max(4, minPINLength) code points")
    func minimum() throws {
        #expect(throws: PINError.tooShort(minimum: 4)) { try CardPIN("123") }
        #expect(throws: PINError.tooShort(minimum: 4)) { try CardPIN("123", minimumLength: 2) }
        #expect(throws: PINError.tooShort(minimum: 6)) { try CardPIN("12345", minimumLength: 6) }
        #expect(throws: Never.self) { try CardPIN("1234") }
        // Code points, not bytes: 4 two-byte characters are enough.
        #expect(throws: Never.self) { try CardPIN("éééé") }
    }

    @Test("At most 63 UTF-8 bytes")
    func maximum() {
        #expect(throws: Never.self) { try CardPIN(String(repeating: "1", count: 63)) }
        #expect(throws: PINError.tooLong) { try CardPIN(String(repeating: "1", count: 64)) }
        #expect(throws: PINError.tooLong) { try CardPIN(String(repeating: "é", count: 32)) }
    }

    @Test("Padded to 64 bytes with 00; hash is LEFT(SHA-256, 16); never printed")
    func paddingAndHash() throws {
        let pin = try CardPIN("1234")
        #expect(pin.padded64.count == 64)
        #expect(pin.padded64.prefix(4) == Data("1234".utf8))
        #expect(pin.padded64.dropFirst(4).allSatisfy { $0 == 0 })
        #expect(pin.hash16 == Data(SHA256.hash(data: Data("1234".utf8)).prefix(16)))
        #expect(!"\(pin)".contains("1234"))
    }
}
