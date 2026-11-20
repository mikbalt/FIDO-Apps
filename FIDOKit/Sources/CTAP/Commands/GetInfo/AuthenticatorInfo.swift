import CardCore
import Foundation

/// The decoded authenticatorGetInfo response: the card's capability matrix.
///
/// The fields brief 02 needs are typed; every other key, known or not, is kept in `otherEntries` and shown,
/// never treated as an error.
public struct AuthenticatorInfo: Sendable, Equatable {
    /// `0x01`, e.g. `["FIDO_2_0", "FIDO_2_1"]`.
    public var versions: [String]
    /// `0x03`.
    public var aaguid: UUID?
    /// `0x04`.
    public var options: AuthenticatorOptions
    /// `0x05`. `nil` when absent (the card then accepts 1024 bytes).
    public var maxMsgSize: Int?
    /// `0x06`, in the card's order of preference, e.g. `[2, 1]`.
    public var pinUvAuthProtocols: [Int]
    /// `0x07`.
    public var maxCredentialCountInList: Int?
    /// `0x0A`, in the card's order of preference.
    public var algorithms: [CredentialAlgorithm]
    /// `0x0D`. 4 when absent.
    public var minPINLength: Int
    /// `0x0E`.
    public var firmwareVersion: UInt64?
    /// `0x14`.
    public var remainingDiscoverableCredentials: Int?
    /// Every key not typed above, in the card's order.
    public var otherEntries: [CBORMapEntry]
    /// The whole response map.
    public var raw: CBORValue

    public static let defaultMinPINLength = 4

    /// - Throws: `GetInfoError` if the response is not a map, has no versions, or a typed key has the
    ///   wrong type.
    public init(cbor: CBORValue) throws {
        guard let entries = cbor.mapEntries else { throw GetInfoError.notAMap }
        raw = cbor
        func value(_ key: Int) -> CBORValue? {
            entries.first { $0.key == CBORValue(key) }?.value
        }
        func invalid(_ key: Int, _ expected: String) -> GetInfoError {
            .invalidField(key: key, name: Self.keyName(key) ?? "key", expected: expected)
        }
        func int(_ key: Int) throws -> Int? {
            guard let field = value(key) else { return nil }
            guard let number = field.intValue, number >= 0 else { throw invalid(key, "an unsigned integer") }
            return number
        }
        func array<T>(_ key: Int, _ expected: String, _ transform: (CBORValue) -> T?) throws -> [T]? {
            guard let field = value(key) else { return nil }
            guard let items = field.arrayValue else { throw invalid(key, "an array of \(expected)") }
            return try items.map { item in
                guard let element = transform(item) else { throw invalid(key, "an array of \(expected)") }
                return element
            }
        }

        guard let versions = try array(0x01, "text", \.textValue), !versions.isEmpty else {
            throw GetInfoError.missingVersions
        }
        self.versions = versions

        if let field = value(0x03) {
            guard let bytes = field.bytesValue, bytes.count == 16 else { throw invalid(0x03, "16 bytes") }
            aaguid = bytes.withUnsafeBytes { UUID(uuid: $0.loadUnaligned(as: uuid_t.self)) }
        } else {
            aaguid = nil
        }

        if let field = value(0x04) {
            guard let map = field.mapEntries else { throw invalid(0x04, "a map") }
            options = AuthenticatorOptions(map: map)
        } else {
            options = AuthenticatorOptions()
        }

        maxMsgSize = try int(0x05)
        pinUvAuthProtocols = try array(0x06, "integers", \.intValue) ?? []
        maxCredentialCountInList = try int(0x07)
        algorithms = try array(0x0A, "algorithm maps") { item in
            guard let type = item[.text("type")]?.textValue, let alg = item[.text("alg")]?.intValue else { return nil }
            return CredentialAlgorithm(type: type, alg: alg)
        } ?? []
        minPINLength = try int(0x0D) ?? Self.defaultMinPINLength
        if let field = value(0x0E) {
            guard let number = field.unsignedValue else { throw invalid(0x0E, "an unsigned integer") }
            firmwareVersion = number
        } else {
            firmwareVersion = nil
        }
        remainingDiscoverableCredentials = try int(0x14)

        let typedKeys: Set<CBORValue> = [0x01, 0x03, 0x04, 0x05, 0x06, 0x07, 0x0A, 0x0D, 0x0E, 0x14]
        otherEntries = entries.filter { !typedKeys.contains($0.key) }
    }

    // MARK: Helpers for the scenarios

    /// `options.clientPin`.
    public var isPINSet: Bool { options.clientPin == true }

    /// The card supports ClientPIN at all (`clientPin` present).
    public var supportsClientPIN: Bool { options.clientPin != nil }

    public var supportsPinProtocol2: Bool { pinUvAuthProtocols.contains(2) }

    /// Shortest PIN the card accepts, in Unicode code points: `max(4, minPINLength)`.
    public var effectiveMinPINLength: Int { max(Self.defaultMinPINLength, minPINLength) }

    /// The study guide §4 name of a GetInfo key, e.g. `versions` for 1, or `nil` if unknown.
    public static func keyName(_ key: Int) -> String? {
        keyNames[key]
    }

    /// The study guide §4 name of a map key, or `0x30` style hex for unknown and non-integer keys.
    public static func displayName(of key: CBORValue) -> String {
        if let number = key.intValue, let name = keyName(number) { return name }
        if let number = key.intValue, (0...0xFF).contains(number) { return "0x\(Hex.byte(UInt8(number)))" }
        return CBORDiagnostic.format(key)
    }

    private static let keyNames: [Int: String] = [
        0x01: "versions", 0x02: "extensions", 0x03: "aaguid", 0x04: "options", 0x05: "maxMsgSize",
        0x06: "pinUvAuthProtocols", 0x07: "maxCredentialCountInList", 0x08: "maxCredentialIdLength",
        0x09: "transports", 0x0A: "algorithms", 0x0B: "maxSerializedLargeBlobArray", 0x0C: "forcePINChange",
        0x0D: "minPINLength", 0x0E: "firmwareVersion", 0x0F: "maxCredBlobLength",
        0x10: "maxRPIDsForSetMinPINLength", 0x11: "preferredPlatformUvAttempts", 0x12: "uvModality",
        0x13: "certifications", 0x14: "remainingDiscoverableCredentials", 0x15: "vendorPrototypeConfigCommands",
    ]
}
