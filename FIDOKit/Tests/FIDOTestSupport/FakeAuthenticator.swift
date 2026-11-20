import CardCore
import CryptoKit
import CTAP
import Foundation
import PinUvAuth

/// A CTAP 2.1 card in memory: SELECT, GetInfo, Reset and ClientPIN with PIN protocol 2.
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
            return (0x00, nil)
        case CTAPCommandCode.clientPIN.rawValue:
            return clientPIN(parameters ?? [:])
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
            let token = Data(repeating: 0x7E, count: 32)
            guard let encrypted = try? PinProtocolTwo().encrypt(secret, token) else { return (0x7F, nil) }
            return (0x00, [2: .bytes(encrypted)])
        default:
            return (0x3E, nil)
        }
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
