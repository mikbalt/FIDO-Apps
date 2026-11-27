import CTAP
import Foundation

/// A parsed authenticatorData (WebAuthn §6.1): `rpIdHash(32) ‖ flags(1) ‖ signCount(4, big endian)`,
/// then attested credential data when AT is set, then extensions when ED is set.
public struct AuthenticatorData: Sendable, Equatable {
    public struct Flags: OptionSet, Sendable, CustomStringConvertible {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// User present.
        public static let userPresent = Flags(rawValue: 0x01)
        /// User verified.
        public static let userVerified = Flags(rawValue: 0x04)
        /// Attested credential data included.
        public static let attestedCredentialData = Flags(rawValue: 0x40)
        /// Extension data included.
        public static let extensionData = Flags(rawValue: 0x80)

        public var description: String { String(format: "0x%02X", rawValue) }
    }

    /// The bytes as received. The signature of an assertion covers exactly these.
    public let raw: Data
    public let rpIdHash: Data
    public let flags: Flags
    public let signCount: UInt32
    public let attestedCredentialData: AttestedCredentialData?
    /// The extensions map, as CBOR bytes, when ED is set. Not interpreted.
    public let extensions: Data?

    private static let headerLength = 37

    public init(parsing data: Data) throws {
        let bytes = Data(data)  // re-base indices at 0
        guard bytes.count >= Self.headerLength else { throw WebAuthnError.truncatedAuthenticatorData }
        raw = bytes
        rpIdHash = bytes.prefix(32)
        flags = Flags(rawValue: bytes[32])
        signCount = bytes[33..<37].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }

        var offset = Self.headerLength
        if flags.contains(.attestedCredentialData) {
            guard bytes.count >= offset + 18 else { throw WebAuthnError.truncatedAuthenticatorData }
            let aaguid = bytes[offset..<(offset + 16)]
            let idLength = Int(bytes[offset + 16]) << 8 | Int(bytes[offset + 17])
            offset += 18
            guard bytes.count >= offset + idLength else { throw WebAuthnError.truncatedAuthenticatorData }
            let credentialId = bytes[offset..<(offset + idLength)]
            offset += idLength
            let keyResult: CBORDecodeResult
            do {
                keyResult = try CBORDecoder.decode(bytes.dropFirst(offset))
            } catch {
                throw WebAuthnError.invalidCBOR("The credential public key does not decode.")
            }
            let cose = Data(bytes[offset..<(offset + keyResult.bytesConsumed)])
            offset += keyResult.bytesConsumed
            attestedCredentialData = AttestedCredentialData(
                aaguid: Data(aaguid), credentialId: Data(credentialId), publicKeyCOSE: cose,
                publicKey: Result { try ES256PublicKey(value: keyResult.value, cose: cose) }
                    .mapError { $0 as? WebAuthnError ?? .invalidCOSEKey("Unusable key.") }
            )
        } else {
            attestedCredentialData = nil
        }

        if flags.contains(.extensionData) {
            let result: CBORDecodeResult
            do {
                result = try CBORDecoder.decode(bytes.dropFirst(offset))
            } catch {
                throw WebAuthnError.invalidCBOR("The extensions do not decode.")
            }
            extensions = Data(bytes[offset..<(offset + result.bytesConsumed)])
            offset += result.bytesConsumed
        } else {
            extensions = nil
        }
        guard offset == bytes.count else { throw WebAuthnError.trailingBytes(count: bytes.count - offset) }
    }
}
