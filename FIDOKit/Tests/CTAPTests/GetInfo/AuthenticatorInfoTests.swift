import CardCore
import CTAP
import Foundation
import Testing

@Suite("GetInfo")
struct AuthenticatorInfoTests {
    /// The GetInfo body of `synthetic-getinfo-full`, reassembled from its 61xx chain.
    private func fixtureBody() throws -> CBORValue {
        let trace = try CTAPFixtures.trace("synthetic-getinfo-full")
        let response = trace.exchanges.filter { $0.label == "GET_INFO" }.reduce(Data()) { $0 + $1.rx }
        #expect(response.first == 0x00)
        return try CBORDecoder.decodeExactly(response.dropFirst()).value
    }

    @Test("The synthetic GetInfo decodes every typed field and keeps the other keys, including an unknown one")
    func fullFixture() throws {
        let info = try AuthenticatorInfo(cbor: fixtureBody())
        #expect(info.versions == ["FIDO_2_0", "FIDO_2_1"])
        #expect(info.aaguid == UUID(uuidString: "2FC0579F-8113-47EA-B116-BB5A8DB9202A"))
        #expect(info.options.clientPin == true)
        #expect(info.options.rk == true)
        #expect(info.options.pinUvAuthToken == true)
        #expect(info.options.makeCredUvNotRqd == true)
        #expect(info.options.raw.count == 6)
        #expect(info.maxMsgSize == 1200)
        #expect(info.pinUvAuthProtocols == [2, 1])
        #expect(info.maxCredentialCountInList == 8)
        #expect(info.algorithms == [.es256])
        #expect(info.minPINLength == 6)
        #expect(info.firmwareVersion == 66051)
        #expect(info.remainingDiscoverableCredentials == 25)
        #expect(info.otherEntries.map(\.key) == [0x02, 0x08, 0x09, 0x30])
        #expect(info.otherEntries.last?.value == 42)
        #expect(AuthenticatorInfo.displayName(of: 0x30) == "0x30")
        #expect(AuthenticatorInfo.displayName(of: 0x09) == "transports")
        #expect(info.isPINSet)
        #expect(info.supportsPinProtocol2)
        #expect(info.effectiveMinPINLength == 6)
    }

    @Test("Defaults when keys are absent")
    func defaults() throws {
        let info = try AuthenticatorInfo(cbor: [1: ["FIDO_2_0"]])
        #expect(info.minPINLength == 4)
        #expect(info.aaguid == nil)
        #expect(info.options == AuthenticatorOptions())
        #expect(info.maxMsgSize == nil)
        #expect(info.pinUvAuthProtocols.isEmpty)
        #expect(info.algorithms.isEmpty)
        #expect(!info.supportsClientPIN)
        #expect(!info.isPINSet)
        #expect(info.otherEntries.isEmpty)
    }

    @Test("clientPin false means supported but not set")
    func pinNotSet() throws {
        let info = try AuthenticatorInfo(cbor: [1: ["FIDO_2_1"], 4: ["clientPin": false], 13: 2])
        #expect(info.supportsClientPIN)
        #expect(!info.isPINSet)
        #expect(info.effectiveMinPINLength == 4)
    }

    @Test("Malformed GetInfo is refused with a specific error")
    func malformed() {
        #expect(throws: GetInfoError.notAMap) { try AuthenticatorInfo(cbor: [1]) }
        #expect(throws: GetInfoError.missingVersions) { try AuthenticatorInfo(cbor: [3: .bytes(Data(count: 16))]) }
        #expect(throws: GetInfoError.invalidField(key: 3, name: "aaguid", expected: "16 bytes")) {
            try AuthenticatorInfo(cbor: [1: ["FIDO_2_0"], 3: .bytes(Data(count: 4))])
        }
    }

    @Test("CTAPClient.getInfo fills the trace card metadata")
    func clientGetInfo() async throws {
        let body = try CBOREncoder.encode([1: ["FIDO_2_0", "FIDO_2_1"], 3: .bytes(Data(repeating: 0xAB, count: 16)), 14: 7])
        let (client, _) = try await CTAPScript.client([
            CTAPScript.Step(tx: "80100000010400", rx: "00" + Hex.compact(body)),
        ])
        let info = try await client.getInfo()
        let card = await client.channel.recorder.trace.card
        #expect(card.versions == info.versions)
        #expect(card.aaguid == info.aaguid)
        #expect(card.firmwareVersion == 7)
    }
}
