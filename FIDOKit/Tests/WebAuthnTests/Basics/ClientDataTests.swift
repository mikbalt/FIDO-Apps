import CryptoKit
import Foundation
import Testing
@testable import WebAuthn

@Suite("clientDataJSON")
struct ClientDataTests {
    @Test("Golden bytes: key order, no whitespace, crossOrigin false")
    func golden() {
        let challenge = Data((0..<32).map(UInt8.init))
        let data = ClientData(kind: .create, challenge: challenge, origin: "https://fidosims.example")
        let expected = #"{"type":"webauthn.create","challenge":"AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8","origin":"https://fidosims.example","crossOrigin":false}"#
        #expect(String(decoding: data.json, as: UTF8.self) == expected)
        #expect(data.hash == Data(SHA256.hash(data: Data(expected.utf8))))
        #expect(data.hash.count == 32)
    }

    @Test("Authentication uses webauthn.get")
    func get() {
        let data = ClientData(kind: .get, challenge: Data([1, 2, 3]), origin: "https://fidosims.example")
        #expect(String(decoding: data.json, as: UTF8.self).hasPrefix(#"{"type":"webauthn.get","challenge":"AQID","#))
    }

    @Test("The origin is JSON-escaped")
    func escaping() throws {
        let data = ClientData(kind: .get, challenge: Data(), origin: "a\"b\\c")
        #expect(String(decoding: data.json, as: UTF8.self).contains(#""origin":"a\"b\\c""#))
        #expect(try ParsedClientData(json: data.json).origin == "a\"b\\c")
    }

    @Test("Parsing reads type, challenge and origin")
    func parse() throws {
        let challenge = Data(repeating: 0xFF, count: 32)
        let data = ClientData(kind: .create, challenge: challenge, origin: "https://fidosims.example")
        let parsed = try ParsedClientData(json: data.json)
        #expect(parsed == ParsedClientData.testValue(type: "webauthn.create", challenge: challenge, origin: "https://fidosims.example"))
        #expect(throws: WebAuthnError.self) { try ParsedClientData(json: Data("nope".utf8)) }
    }
}

extension ParsedClientData {
    fileprivate static func testValue(type: String, challenge: Data, origin: String) -> ParsedClientData {
        try! ParsedClientData(json: Data(#"{"type":"\#(type)","challenge":"\#(challenge.base64URLEncoded)","origin":"\#(origin)"}"#.utf8))
    }
}
