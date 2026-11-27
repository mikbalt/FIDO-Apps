import CryptoKit
import CTAP
import Foundation

/// A COSE ES256 public key (`{1: 2, 3: -7, -1: 1, -2: x, -3: y}`): the CryptoKit key, plus the original
/// COSE bytes, which are what gets stored.
public struct ES256PublicKey: Sendable, Equatable {
    public let cose: Data
    public let key: P256.Signing.PublicKey

    public init(cose: Data) throws {
        let value: CBORValue
        do {
            value = try CBORDecoder.decodeExactly(cose).value
        } catch {
            throw WebAuthnError.invalidCOSEKey("Not one CBOR item.")
        }
        try self.init(value: value, cose: cose)
    }

    init(value: CBORValue, cose: Data) throws {
        guard value.mapEntries != nil else { throw WebAuthnError.invalidCOSEKey("Not a map.") }
        guard value[1]?.intValue == 2 else { throw WebAuthnError.invalidCOSEKey("kty is not EC2 (2).") }
        guard value[3]?.intValue == -7 else { throw WebAuthnError.invalidCOSEKey("alg is not ES256 (-7).") }
        guard value[CBORValue(-1)]?.intValue == 1 else { throw WebAuthnError.invalidCOSEKey("crv is not P-256 (1).") }
        guard let x = value[CBORValue(-2)]?.bytesValue, x.count == 32,
              let y = value[CBORValue(-3)]?.bytesValue, y.count == 32 else {
            throw WebAuthnError.invalidCOSEKey("x and y must be 32 bytes.")
        }
        do {
            key = try P256.Signing.PublicKey(x963Representation: Data([0x04]) + x + y)
        } catch {
            throw WebAuthnError.invalidCOSEKey("The point is not on P-256.")
        }
        self.cose = cose
    }

    public static func == (lhs: ES256PublicKey, rhs: ES256PublicKey) -> Bool { lhs.cose == rhs.cose }
}
