import CardCore
import CTAP
import Foundation

/// authenticatorClientPIN (`0x06`) with PIN protocol 2.
///
/// Subcommands that carry PIN material (setPIN, changePIN, the token subcommands) are sent `sensitive`, so
/// exports and the Safe view redact them. PINs, shared secrets and tokens are never logged.
public struct ClientPIN: Sendable {
    public let client: CTAPClient
    public let pinProtocol: PinProtocolTwo

    public init(client: CTAPClient, pinProtocol: PinProtocolTwo = PinProtocolTwo()) {
        self.client = client
        self.pinProtocol = pinProtocol
    }

    /// Request keys (CTAP 2.1 §6.5.5).
    private enum Key {
        static let pinUvAuthProtocol: CBORValue = 0x01
        static let subCommand: CBORValue = 0x02
        static let keyAgreement: CBORValue = 0x03
        static let pinUvAuthParam: CBORValue = 0x04
        static let newPinEnc: CBORValue = 0x05
        static let pinHashEnc: CBORValue = 0x06
        static let permissions: CBORValue = 0x09
        static let rpId: CBORValue = 0x0A
    }

    /// Response keys.
    private enum ResponseKey {
        static let keyAgreement: CBORValue = 0x01
        static let pinUvAuthToken: CBORValue = 0x02
        static let pinRetries: CBORValue = 0x03
    }

    private enum SubCommand: Int {
        case getPINRetries = 0x01
        case getKeyAgreement = 0x02
        case setPIN = 0x03
        case changePIN = 0x04
        case getPinToken = 0x05
        case getPinUvAuthTokenUsingPinWithPermissions = 0x09
    }

    // MARK: Subcommands

    /// `0x01` getPINRetries.
    public func getPINRetries() async throws -> Int {
        let body = try await send(.getPINRetries, [:], label: "CLIENT_PIN_RETRIES", sensitive: false)
        guard let retries = body?[ResponseKey.pinRetries]?.intValue else {
            throw CTAPClientError.unexpectedResponse(label: "CLIENT_PIN_RETRIES", reason: "No pinRetries.")
        }
        return retries
    }

    /// `0x02` getKeyAgreement, then ECDH with a fresh platform key.
    public func keyAgreement() async throws -> PinProtocolTwo.KeyAgreement {
        let body = try await send(.getKeyAgreement, [:], label: "CLIENT_PIN_KEY_AGREEMENT", sensitive: false)
        guard let cardKey = body?[ResponseKey.keyAgreement] else {
            throw CTAPClientError.unexpectedResponse(label: "CLIENT_PIN_KEY_AGREEMENT", reason: "No keyAgreement.")
        }
        return try pinProtocol.agree(with: cardKey)
    }

    /// `0x03` setPIN: `newPinEnc = encrypt(shared, pad64(PIN))`, `pinUvAuthParam = authenticate(shared, newPinEnc)`.
    public func setPIN(_ pin: CardPIN, using agreement: PinProtocolTwo.KeyAgreement) async throws {
        let secret = agreement.sharedSecret
        let newPinEnc = try pinProtocol.encrypt(secret, pin.padded64)
        _ = try await send(.setPIN, [
            Key.keyAgreement: agreement.platformKey,
            Key.pinUvAuthParam: .bytes(PinProtocolTwo.authenticate(secret, newPinEnc)),
            Key.newPinEnc: .bytes(newPinEnc),
        ], label: "CLIENT_PIN_SET", sensitive: true)
    }

    /// `0x04` changePIN: `pinHashEnc = encrypt(shared, LEFT(SHA-256(current), 16))`,
    /// `pinUvAuthParam = authenticate(shared, newPinEnc ‖ pinHashEnc)`.
    ///
    /// On `0x31` PIN_INVALID the error message gets the remaining retries, read with getPINRetries.
    public func changePIN(current: CardPIN, new: CardPIN, using agreement: PinProtocolTwo.KeyAgreement) async throws {
        let secret = agreement.sharedSecret
        let newPinEnc = try pinProtocol.encrypt(secret, new.padded64)
        let pinHashEnc = try pinProtocol.encrypt(secret, current.hash16)
        _ = try await send(.changePIN, [
            Key.keyAgreement: agreement.platformKey,
            Key.pinUvAuthParam: .bytes(PinProtocolTwo.authenticate(secret, newPinEnc + pinHashEnc)),
            Key.newPinEnc: .bytes(newPinEnc),
            Key.pinHashEnc: .bytes(pinHashEnc),
        ], label: "CLIENT_PIN_CHANGE", sensitive: true)
    }

    /// `0x09` getPinUvAuthTokenUsingPinWithPermissions: `token = decrypt(shared, response[0x02])`.
    public func pinUvAuthToken(
        pin: CardPIN, permissions: PinUvAuthPermissions, rpId: String?, using agreement: PinProtocolTwo.KeyAgreement
    ) async throws -> Data {
        var parameters: [CBORMapEntry] = [
            CBORMapEntry(key: Key.keyAgreement, value: agreement.platformKey),
            CBORMapEntry(key: Key.pinHashEnc, value: .bytes(try pinProtocol.encrypt(agreement.sharedSecret, pin.hash16))),
            CBORMapEntry(key: Key.permissions, value: .unsigned(UInt64(permissions.rawValue))),
        ]
        if let rpId {
            parameters.append(CBORMapEntry(key: Key.rpId, value: .text(rpId)))
        }
        return try await token(.getPinUvAuthTokenUsingPinWithPermissions, parameters, agreement)
    }

    /// `0x05` getPinToken, for CTAP 2.0 cards (GetInfo has no `pinUvAuthToken` option).
    public func pinToken(pin: CardPIN, using agreement: PinProtocolTwo.KeyAgreement) async throws -> Data {
        try await token(.getPinToken, [
            CBORMapEntry(key: Key.keyAgreement, value: agreement.platformKey),
            CBORMapEntry(key: Key.pinHashEnc, value: .bytes(try pinProtocol.encrypt(agreement.sharedSecret, pin.hash16))),
        ], agreement)
    }

    // MARK: Private

    private func token(
        _ subCommand: SubCommand, _ parameters: [CBORMapEntry], _ agreement: PinProtocolTwo.KeyAgreement
    ) async throws -> Data {
        let body = try await send(subCommand, parameters, label: "CLIENT_PIN_TOKEN", sensitive: true)
        guard let encrypted = body?[ResponseKey.pinUvAuthToken]?.bytesValue else {
            throw CTAPClientError.unexpectedResponse(label: "CLIENT_PIN_TOKEN", reason: "No pinUvAuthToken.")
        }
        return try pinProtocol.decrypt(agreement.sharedSecret, encrypted)
    }

    private func send(
        _ subCommand: SubCommand, _ parameters: [CBORMapEntry], label: String, sensitive: Bool
    ) async throws -> CBORValue? {
        let request: [CBORMapEntry] = [
            CBORMapEntry(key: Key.pinUvAuthProtocol, value: CBORValue(PinProtocolTwo.version)),
            CBORMapEntry(key: Key.subCommand, value: CBORValue(subCommand.rawValue)),
        ] + parameters
        do {
            return try await client.send(.clientPIN, parameters: .map(request), label: label, sensitive: sensitive)
        } catch var error as CTAPError {
            error.detail = try await detail(for: error.code)
            throw error
        }
    }

    private func send(
        _ subCommand: SubCommand, _ parameters: KeyValuePairs<CBORValue, CBORValue>, label: String, sensitive: Bool
    ) async throws -> CBORValue? {
        try await send(subCommand, parameters.map { CBORMapEntry(key: $0.key, value: $0.value) }, label: label, sensitive: sensitive)
    }

    /// The extra text brief 02 asks for on PIN errors.
    private func detail(for code: UInt8) async throws -> String? {
        switch code {
        case CTAPError.pinInvalid:
            // The retries are worth an extra command: the tester needs them before trying again.
            guard let retries = try? await getPINRetries() else { return "Retries unknown." }
            return "\(retries) \(retries == 1 ? "retry" : "retries") left."
        case CTAPError.pinBlocked:
            return "Reset the card to use it again."
        case CTAPError.pinAuthBlocked:
            return "Too many wrong PINs in a row: remove the card and tap again."
        case CTAPError.pinNotSet:
            return "Use Set PIN first."
        case CTAPError.pinPolicyViolation:
            return "The new PIN does not meet the card's PIN policy."
        default:
            return nil
        }
    }
}
