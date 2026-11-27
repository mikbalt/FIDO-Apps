import Foundation
import Testing
@testable import WebAuthn

@Suite("base64url and options JSON")
struct Base64URLAndOptionsTests {
    @Test("RFC 4648 vectors, no padding, URL alphabet")
    func vectors() {
        #expect(Data("f".utf8).base64URLEncoded == "Zg")
        #expect(Data("fo".utf8).base64URLEncoded == "Zm8")
        #expect(Data("foo".utf8).base64URLEncoded == "Zm9v")
        #expect(Data([0xFB, 0xFF]).base64URLEncoded == "-_8")
        #expect(Data(base64URLEncoded: "-_8") == Data([0xFB, 0xFF]))
        #expect(Data(base64URLEncoded: "Zg") == Data("f".utf8))
        #expect(Data(base64URLEncoded: "Zg==") == nil)
        #expect(Data(base64URLEncoded: "+/8") == nil)
        #expect(Data(base64URLEncoded: "Z") == nil)
    }

    @Test("Creation options round-trip as JSON with base64url binary fields")
    func creation() throws {
        let options = CreationOptions(
            rp: .init(id: "fidosims.example", name: "FIDOSims"),
            user: .init(id: Data([0xFB, 0xFF]), name: "nusa-042", displayName: "nusa-042"),
            challenge: Data([1, 2, 3]),
            authenticatorSelection: .init(residentKey: "discouraged", userVerification: "required")
        )
        let json = try WebAuthnJSON.encoder().encode(options)
        let text = String(decoding: json, as: UTF8.self)
        #expect(text.contains(#""challenge":"AQID""#))
        #expect(text.contains(#""id":"-_8""#))
        #expect(text.contains(#""attestation":"none""#))
        #expect(text.contains(#""alg":-7"#))
        #expect(try WebAuthnJSON.decoder().decode(CreationOptions.self, from: json) == options)
    }

    @Test("Request options round-trip, and bad base64url is rejected")
    func request() throws {
        let options = RequestOptions(
            rpId: "fidosims.example", challenge: Data([9]), allowCredentials: [CredentialDescriptor(id: Data([0xFB, 0xFF]))]
        )
        let json = try WebAuthnJSON.encoder().encode(options)
        #expect(try WebAuthnJSON.decoder().decode(RequestOptions.self, from: json) == options)
        let bad = Data(#"{"rpId":"x","challenge":"@@","allowCredentials":[],"userVerification":"required"}"#.utf8)
        #expect(throws: DecodingError.self) { try WebAuthnJSON.decoder().decode(RequestOptions.self, from: bad) }
    }
}
