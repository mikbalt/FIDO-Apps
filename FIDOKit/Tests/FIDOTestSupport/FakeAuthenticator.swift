import CardCore
import CryptoKit
import CTAP
import Foundation
import PinUvAuth

/// A CTAP 2.1 card in memory: SELECT, GetInfo, Reset, ClientPIN with PIN protocol 2, MakeCredential and
/// GetAssertion (ES256, `none` attestation).
///
/// For tests only. It checks every pinUvAuthParam and PIN hash like a real card, so a wrong formula in the
/// client fails the test.
public actor FakeAuthenticator: CardTransport {
    public nonisolated let kind: TransportKind = .mock

    public private(set) var pin: Data?
    public private(set) var retries = 8
    public var minPINLength = 4
    public var resetAllowed = true
    public var pinProtocols = [2, 1]
    /// Every CTAP request received: command byte, then the decoded parameters.
    public private(set) var requests: [(command: UInt8, parameters: CBORValue?)] = []

    /// A credential made by MakeCredential. The private key never leaves the fake.
    public struct Credential: Sendable {
        public let id: Data
        public let rpId: String
        public let userId: Data
        public let discoverable: Bool
        public let publicKey: P256.Signing.PublicKey
        fileprivate let privateKey: P256.Signing.PrivateKey
        public fileprivate(set) var signCount: UInt32
    }

    public private(set) var credentials: [Credential] = []
    /// When false the card always answers signCount 0, like cards that do not keep a counter.
    public private(set) var countsSignatures = true
    /// What the last PIN token was issued for: permission bits and rpId.
    public private(set) var tokenGrant: (permissions: Int, rpId: String?)?

    private var keyAgreementKey: P256.KeyAgreement.PrivateKey?
    private var consecutiveWrongPINs = 0
    private let clock = ContinuousClock()

    public init(pin: String? = nil) {
        self.pin = pin.map { Data($0.precomposedStringWithCanonicalMapping.utf8) }
    }

    public func configure(minPINLength: Int? = nil, resetAllowed: Bool? = nil, pinProtocols: [Int]? = nil, retries: Int? = nil) {
        if let minPINLength { self.minPINLength = minPINLength }
        if let resetAllowed { self.resetAllowed = resetAllowed }
        if let pinProtocols { self.pinProtocols = pinProtocols }
        if let retries { self.retries = retries }
    }

    public func setCountsSignatures(_ value: Bool) { countsSignatures = value }

    public var commandsReceived: [UInt8] { requests.map(\.command) }

    // MARK: CardTransport

    public func open(prompt: String) async throws -> CardConnection {
        let now = clock.now
        return CardConnection(sessionStartedAt: now, cardDetectedAt: now, initialSelectedAID: FIDOApplet.aid)
    }

    public func transmit(_ command: Data) async throws -> RawExchange {
        let start = clock.now
        let response = respond(to: [UInt8](command))
        return RawExchange(command: command, response: response, startedAt: start, endedAt: clock.now)
    }

    public func close(errorMessage: String?) async {}

    // MARK: APDU

    private func respond(to apdu: [UInt8]) -> ResponseAPDU {
        if Data(apdu) == (try? CommandAPDU.selectFIDO.encoded(.short)) {
            return ResponseAPDU(data: Data("FIDO_2_0".utf8), sw: .success)
        }
        guard apdu.count >= 6, apdu[0] == 0x80, apdu[1] == 0x10 else {
            return ResponseAPDU(data: Data(), sw: .insNotSupported)
        }
        let length = Int(apdu[4])
        guard apdu.count >= 5 + length, length >= 1 else { return ResponseAPDU(data: Data(), sw: .wrongLength) }
        let request = Data(apdu[5..<(5 + length)])
        let parameters = request.count > 1 ? try? CBORDecoder.decodeExactly(request.dropFirst()).value : nil
        requests.append((request[request.startIndex], parameters))
        let (status, body) = ctap(request[request.startIndex], parameters)
        var data = Data([status])
        if let body, let encoded = try? CBOREncoder.encode(body) {
            data += encoded
        }
        return ResponseAPDU(data: data, sw: .success)
    }

    // MARK: CTAP

    private func ctap(_ command: UInt8, _ parameters: CBORValue?) -> (UInt8, CBORValue?) {
        switch command {
        case CTAPCommandCode.getInfo.rawValue:
            return (0x00, [
                1: ["FIDO_2_0", "FIDO_2_1"],
                3: .bytes(Data(repeating: 0xA5, count: 16)),
                4: ["rk": true, "up": true, "clientPin": .bool(pin != nil), "pinUvAuthToken": true],
                6: .array(pinProtocols.map { CBORValue($0) }),
                13: CBORValue(minPINLength),
            ])
        case CTAPCommandCode.reset.rawValue:
            guard resetAllowed else { return (CTAPError.notAllowed, nil) }
            pin = nil
            retries = 8
            credentials = []
            tokenGrant = nil
            return (0x00, nil)
        case CTAPCommandCode.clientPIN.rawValue:
            return clientPIN(parameters ?? [:])
        case CTAPCommandCode.makeCredential.rawValue:
            return makeCredential(parameters ?? [:])
        case CTAPCommandCode.getAssertion.rawValue:
            return getAssertion(parameters ?? [:])
        default:
            return (0x01, nil)
        }
    }

    private func clientPIN(_ p: CBORValue) -> (UInt8, CBORValue?) {
        guard p[1] == 2 else { return (0x02, nil) }
        switch p[2]?.intValue {
        case 0x01:
            return (0x00, [3: CBORValue(retries)])
        case 0x02:
            let key = P256.KeyAgreement.PrivateKey()
            keyAgreementKey = key
            return (0x00, [1: PinProtocolTwo.coseKey(key.publicKey)])
        case 0x03:
            guard pin == nil else { return (CTAPError.notAllowed, nil) }
            guard let secret = sharedSecret(p), let newPinEnc = p[5]?.bytesValue, let param = p[4]?.bytesValue else {
                return (0x14, nil)
            }
            guard param == PinProtocolTwo.authenticate(secret, newPinEnc) else { return (0x33, nil) }
            return storeNewPIN(newPinEnc, secret)
        case 0x04:
            guard let current = pin else { return (CTAPError.pinNotSet, nil) }
            guard retries > 0 else { return (CTAPError.pinBlocked, nil) }
            guard let secret = sharedSecret(p), let newPinEnc = p[5]?.bytesValue, let pinHashEnc = p[6]?.bytesValue,
                  let param = p[4]?.bytesValue else { return (0x14, nil) }
            guard param == PinProtocolTwo.authenticate(secret, newPinEnc + pinHashEnc) else { return (0x33, nil) }
            guard checkPINHash(pinHashEnc, secret, current) else { return wrongPIN() }
            return storeNewPIN(newPinEnc, secret)
        case 0x05, 0x09:
            guard let current = pin else { return (CTAPError.pinNotSet, nil) }
            guard let secret = sharedSecret(p), let pinHashEnc = p[6]?.bytesValue else { return (0x14, nil) }
            guard checkPINHash(pinHashEnc, secret, current) else { return wrongPIN() }
            let token = Self.pinToken
            tokenGrant = (p[2]?.intValue == 0x09 ? (p[9]?.intValue ?? 0) : 0x03, p[10]?.textValue)
            guard let encrypted = try? PinProtocolTwo().encrypt(secret, token) else { return (0x7F, nil) }
            return (0x00, [2: .bytes(encrypted)])
        default:
            return (0x3E, nil)
        }
    }

    private static let pinToken = Data(repeating: 0x7E, count: 32)

    /// Checks `pinUvAuthParam = HMAC(token, clientDataHash)`, protocol 2, and that the last token was issued
    /// for `permission` and `rpId`. Returns the CTAP error, or `nil` when it is fine.
    private func checkPinUvAuth(_ p: CBORValue, paramKey: Int, protocolKey: Int, hash: Data, permission: Int, rpId: String) -> UInt8? {
        guard let param = p[CBORValue(paramKey)]?.bytesValue else { return pin == nil ? nil : 0x36 }
        guard p[CBORValue(protocolKey)]?.intValue == 2 else { return 0x14 }
        guard let grant = tokenGrant, grant.permissions & permission != 0, grant.rpId == nil || grant.rpId == rpId else {
            return 0x33
        }
        return param == PinProtocolTwo.authenticate(token: Self.pinToken, hash) ? nil : 0x33
    }

    private func authData(rpId: String, flags: UInt8, signCount: UInt32, attested: (Data, Credential)? = nil) -> Data {
        var data = Data(SHA256.hash(data: Data(rpId.utf8)))
        data.append(flags)
        data += withUnsafeBytes(of: signCount.bigEndian) { Data($0) }
        if let (aaguid, credential) = attested {
            let point = credential.publicKey.x963Representation
            let cose: CBORValue = [
                1: 2, 3: -7, CBORValue(-1): 1,
                CBORValue(-2): .bytes(point[1..<33]), CBORValue(-3): .bytes(point[33..<65]),
            ]
            data += aaguid
            data += withUnsafeBytes(of: UInt16(credential.id.count).bigEndian) { Data($0) }
            data += credential.id
            data += (try? CBOREncoder.encode(cose)) ?? Data()
        }
        return data
    }

    private func makeCredential(_ p: CBORValue) -> (UInt8, CBORValue?) {
        guard let hash = p[1]?.bytesValue, hash.count == 32, let rpId = p[2]?["id"]?.textValue,
              let userId = p[3]?["id"]?.bytesValue, let algorithms = p[4]?.arrayValue else { return (0x14, nil) }
        guard algorithms.contains(where: { $0["alg"]?.intValue == -7 }) else { return (0x26, nil) }
        let options = p[7]
        // Never `up: false`, and never `uv` together with pinUvAuthParam.
        if options?["up"] != nil || (options?["uv"] != nil && p[8] != nil) { return (0x2C, nil) }
        if let error = checkPinUvAuth(p, paramKey: 8, protocolKey: 9, hash: hash, permission: 0x01, rpId: rpId) {
            return (error, nil)
        }
        let key = P256.Signing.PrivateKey()
        let credential = Credential(
            id: Data((0..<32).map { _ in UInt8.random(in: 0...255) }), rpId: rpId, userId: userId,
            discoverable: options?["rk"]?.boolValue == true, publicKey: key.publicKey, privateKey: key, signCount: 0
        )
        credentials.append(credential)
        let data = authData(rpId: rpId, flags: pin == nil ? 0x41 : 0x45, signCount: 0, attested: (Data(repeating: 0xA5, count: 16), credential))
        return (0x00, [1: "none", 2: .bytes(data), 3: []])
    }

    private func getAssertion(_ p: CBORValue) -> (UInt8, CBORValue?) {
        guard let rpId = p[1]?.textValue, let hash = p[2]?.bytesValue, hash.count == 32 else { return (0x14, nil) }
        if p[5]?["rk"] != nil || p[5]?["up"]?.boolValue == false || (p[5]?["uv"] != nil && p[6] != nil) { return (0x2C, nil) }
        if let error = checkPinUvAuth(p, paramKey: 6, protocolKey: 7, hash: hash, permission: 0x02, rpId: rpId) {
            return (error, nil)
        }
        let allowed = p[3]?.arrayValue?.compactMap { $0["id"]?.bytesValue }
        guard let index = credentials.firstIndex(where: { credential in
            credential.rpId == rpId && (allowed?.contains(credential.id) ?? credential.discoverable)
        }) else { return (0x2E, nil) }
        if countsSignatures { credentials[index].signCount += 1 }
        let credential = credentials[index]
        let data = authData(rpId: rpId, flags: pin == nil ? 0x01 : 0x05, signCount: credential.signCount)
        guard let signature = try? credential.privateKey.signature(for: data + hash) else { return (0x7F, nil) }
        var response: [CBORMapEntry] = [
            CBORMapEntry(key: 1, value: ["id": .bytes(credential.id), "type": "public-key"]),
            CBORMapEntry(key: 2, value: .bytes(data)),
            CBORMapEntry(key: 3, value: .bytes(signature.derRepresentation)),
        ]
        if credential.discoverable || allowed?.count != 1 {
            response.append(CBORMapEntry(key: 4, value: ["id": .bytes(credential.userId)]))
        }
        return (0x00, .map(response))
    }

    private func sharedSecret(_ p: CBORValue) -> PinUvAuthSharedSecret? {
        guard let key = keyAgreementKey, let platform = p[3],
              let peer = try? PinProtocolTwo.publicKey(fromCOSE: platform),
              let shared = try? key.sharedSecretFromKeyAgreement(with: peer) else { return nil }
        return PinUvAuthSharedSecret(z: shared.withUnsafeBytes { Data($0) })
    }

    private func checkPINHash(_ pinHashEnc: Data, _ secret: PinUvAuthSharedSecret, _ current: Data) -> Bool {
        guard let hash = try? PinProtocolTwo().decrypt(secret, pinHashEnc) else { return false }
        return hash == Data(SHA256.hash(data: current).prefix(16))
    }

    private func wrongPIN() -> (UInt8, CBORValue?) {
        retries -= 1
        consecutiveWrongPINs += 1
        keyAgreementKey = nil
        if retries == 0 { return (CTAPError.pinBlocked, nil) }
        if consecutiveWrongPINs >= 3 { return (CTAPError.pinAuthBlocked, nil) }
        return (CTAPError.pinInvalid, nil)
    }

    private func storeNewPIN(_ newPinEnc: Data, _ secret: PinUvAuthSharedSecret) -> (UInt8, CBORValue?) {
        guard let padded = try? PinProtocolTwo().decrypt(secret, newPinEnc), padded.count == 64 else { return (0x02, nil) }
        let utf8 = Data(padded.prefix { $0 != 0 })
        guard String(decoding: utf8, as: UTF8.self).unicodeScalars.count >= minPINLength else {
            return (CTAPError.pinPolicyViolation, nil)
        }
        pin = utf8
        retries = 8
        consecutiveWrongPINs = 0
        return (0x00, nil)
    }
}
