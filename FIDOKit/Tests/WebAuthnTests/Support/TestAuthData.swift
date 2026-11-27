import CryptoKit
import CTAP
import Foundation
@testable import WebAuthn

/// Builds authenticatorData and COSE keys from CryptoKit keys, so no test depends on a "real" fixture.
enum TestAuthData {
    static func cose(_ key: P256.Signing.PublicKey) -> Data {
        let point = key.x963Representation
        let value: CBORValue = [
            1: 2, 3: -7, CBORValue(-1): 1,
            CBORValue(-2): .bytes(point[1..<33]), CBORValue(-3): .bytes(point[33..<65]),
        ]
        return try! CBOREncoder.encode(value)
    }

    static func build(
        rpId: String = "fidosims.example", flags: UInt8, signCount: UInt32 = 0,
        credentialId: Data? = nil, key: P256.Signing.PublicKey? = nil, aaguid: Data = Data(repeating: 0xA5, count: 16),
        extensions: Data? = nil
    ) -> Data {
        var data = Data(SHA256.hash(data: Data(rpId.utf8)))
        data.append(flags)
        data += withUnsafeBytes(of: signCount.bigEndian) { Data($0) }
        if let credentialId, let key {
            data += aaguid
            data += withUnsafeBytes(of: UInt16(credentialId.count).bigEndian) { Data($0) }
            data += credentialId
            data += cose(key)
        }
        if let extensions { data += extensions }
        return data
    }
}
