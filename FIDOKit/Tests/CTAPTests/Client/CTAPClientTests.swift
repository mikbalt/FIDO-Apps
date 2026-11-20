import CardCore
import CTAP
import Foundation
import Testing

@Suite("CTAP client")
struct CTAPClientTests {
    private typealias Step = CTAPScript.Step

    @Test("Wraps command ‖ CBOR in NFCCTAP_MSG with P1 00, decodes a 00 + CBOR body and marks ctapStatus")
    func success() async throws {
        // ClientPIN getPINRetries: {1: 2, 2: 1} -> {3: 8}
        let (client, transport) = try await CTAPScript.client([
            Step(tx: "8010000006" + "06A201020201" + "00", rx: "00A10308"),
        ])
        let body = try await client.send(.clientPIN, parameters: [2: 1, 1: 2], label: "CLIENT_PIN_RETRIES")
        #expect(body == [3: 8])
        #expect(await transport.remainingExchanges == 0)
        let exchanges = await client.channel.recorder.trace.exchanges
        #expect(exchanges.last?.ctapStatus == 0x00)
        #expect(exchanges.last?.label == "CLIENT_PIN_RETRIES")
    }

    @Test("Status 00 with an empty body returns nil")
    func emptyBody() async throws {
        let (client, _) = try await CTAPScript.client([Step(tx: "80100000010700", rx: "00")])
        #expect(try await client.send(.reset, parameters: nil, label: "RESET") == nil)
    }

    @Test("A non-zero status throws CTAPError with its name and records the status")
    func errorStatus() async throws {
        let (client, _) = try await CTAPScript.client([Step(tx: "80100000010700", rx: "30")])
        await #expect(throws: CTAPError(code: 0x30, name: "CTAP2_ERR_NOT_ALLOWED")) {
            try await client.send(.reset, parameters: nil, label: "RESET")
        }
        #expect(await client.channel.recorder.trace.exchanges.last?.ctapStatus == 0x30)
    }

    @Test("A non-9000 SW throws ChannelError.unexpectedStatus (e.g. 6D00 on a CTAP1-only card)")
    func swFailure() async throws {
        let (client, _) = try await CTAPScript.client([Step(tx: "80100000010400", sw: "6D00")])
        await #expect(throws: ChannelError.unexpectedStatus(.insNotSupported)) {
            try await client.send(.getInfo, parameters: nil, label: "GET_INFO")
        }
    }

    @Test("9000 without a status byte, and invalid CBOR, are client errors")
    func badResponses() async throws {
        let (empty, _) = try await CTAPScript.client([Step(tx: "80100000010400")])
        await #expect(throws: CTAPClientError.missingStatus(label: "GET_INFO")) {
            try await empty.send(.getInfo, parameters: nil, label: "GET_INFO")
        }
        let (float, _) = try await CTAPScript.client([Step(tx: "80100000010400", rx: "00F93C00")])
        await #expect(throws: CTAPClientError.invalidCBOR(label: "GET_INFO", .floatNotSupported(offset: 0))) {
            try await float.send(.getInfo, parameters: nil, label: "GET_INFO")
        }
    }

    @Test(
        "Status-code names follow the study guide §9 table",
        arguments: [
            (UInt8(0x00), "CTAP2_OK"), (0x01, "CTAP1_ERR_INVALID_COMMAND"), (0x0B, "CTAP1_ERR_INVALID_CHANNEL"),
            (0x11, "CTAP2_ERR_CBOR_UNEXPECTED_TYPE"), (0x31, "CTAP2_ERR_PIN_INVALID"),
            (0x34, "CTAP2_ERR_PIN_AUTH_BLOCKED"), (0x40, "CTAP2_ERR_UNAUTHORIZED_PERMISSION"),
            (0x7F, "CTAP1_ERR_OTHER"), (0xE5, "CTAP2_ERR_EXTENSION_SPECIFIC_0xE5"),
            (0xF3, "CTAP2_ERR_VENDOR_SPECIFIC_0xF3"), (0x13, "CTAP_STATUS_0x13"),
        ]
    )
    func statusNames(code: UInt8, name: String) {
        #expect(CTAPStatusCode.name(code) == name)
    }

    @Test("CTAPError maps to a ctap trace error")
    func traceError() {
        let error = TraceError(CTAPError(code: 0x31, detail: "7 retries left."))
        #expect(error.domain == .ctap)
        #expect(error.code == "0x31")
        #expect(error.name == "CTAP2_ERR_PIN_INVALID")
        #expect(error.message.hasSuffix("7 retries left."))
    }
}
