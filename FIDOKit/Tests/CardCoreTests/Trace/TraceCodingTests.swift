import CardCore
import Foundation
import Testing

@Suite("Trace JSON")
struct TraceCodingTests {
    @Test("All synthetic fixtures decode", arguments: Fixtures.synthetic)
    func fixturesDecode(name: String) throws {
        let trace = try Fixtures.trace(name)
        #expect(Trace.supportedSchemaVersions.contains(trace.schemaVersion))
        #expect(!trace.exchanges.isEmpty)
        if trace.schemaVersion == 1 {
            #expect(trace.sessionStartedTime == 0)
        } else {
            #expect(trace.scenarioStartedTime == 0)
        }
    }

    @Test("v1 fixtures decode as v1, with no v2 fields, and re-encode without them", arguments: Fixtures.syntheticV1)
    func v1Fixtures(name: String) throws {
        let trace = try Fixtures.trace(name)
        #expect(trace.schemaVersion == 1)
        #expect(trace.scenario == nil)
        #expect(trace.outcome == nil)
        #expect(trace.scenarioStartedTime == nil)
        let json = String(decoding: try trace.jsonData(), as: UTF8.self)
        #expect(json.contains(#""schemaVersion" : 1"#))
        for key in ["scenario", "outcome", "aaguid", "versions", "firmwareVersion"] {
            #expect(!json.contains("\"\(key)\""))
        }
    }

    @Test("The v2 fixture decodes every v2 field and event type")
    func v2Fixture() throws {
        let trace = try Fixtures.trace("synthetic-v2-timeline")
        #expect(trace.schemaVersion == 2)
        #expect(trace.scenario == .diagnostics)
        #expect(trace.outcome == .success)
        #expect(trace.card.aaguid == UUID(uuidString: "2FC0579F-8113-47EA-B116-BB5A8DB9202A"))
        #expect(trace.card.versions == ["FIDO_2_0", "FIDO_2_1"])
        #expect(trace.card.firmwareVersion == nil)
        #expect(trace.commands.map(\.label) == ["SELECT_FIDO", "GET_INFO"])
        #expect(trace.commands[1].ctapCommand == 0x04)
        #expect(trace.commands[1].ctapStatus == 0x00)
        #expect(trace.commands[1].exchanges == [2, 3])
        #expect(trace.hostSteps == [HostStepEvent(label: "CBOR_DECODE", tStart: 1_603_300_000, tEnd: 1_603_500_000)])
        #expect(trace.warnings.map(\.code) == [.cborNonShortestInteger])
        #expect(trace.events.contains(.status(t: 1_563_000_000, value: .processing)))
        #expect(trace.scenarioEndedTime == 1_700_000_000)
    }

    @Test("Outcome errors, unknown scenarios and unknown warning codes round-trip")
    func v2Values() throws {
        var trace = try Fixtures.trace("synthetic-v2-timeline")
        trace.scenario = .unknown("enrollFingerprint")
        trace.outcome = .failure(TraceError(domain: .ctap, code: "0x31", name: "CTAP2_ERR_PIN_INVALID", message: "PIN invalid"))
        trace.events.append(.warning(WarningEvent(t: 5, code: TraceWarningCode(rawValue: "FUTURE_CHECK"), message: "x")))
        trace.events.append(.status(t: 6, value: .other(0x07)))
        trace.events.append(.status(t: 7, value: .other(nil)))
        trace.card.firmwareVersion = 0x0102_0304
        let json = String(decoding: try trace.jsonData(), as: UTF8.self)
        #expect(json.contains(#""domain" : "ctap""#))
        #expect(json.contains(#""scenario" : "enrollFingerprint""#))
        #expect(json.contains(#""value" : "07""#))
        #expect(json.contains(#""value" : "NONE""#))
        #expect(try Trace(jsonData: Data(json.utf8)) == trace)
    }

    @Test("An unsupported schema version is refused with a clear error")
    func unsupportedVersion() throws {
        var json = String(decoding: try Fixtures.trace("synthetic-v2-timeline").jsonData(), as: UTF8.self)
        json = json.replacingOccurrences(of: #""schemaVersion" : 2"#, with: #""schemaVersion" : 3"#)
        #expect(throws: DecodingError.self) { try Trace(jsonData: Data(json.utf8)) }
    }

    @Test("decode(encode(trace)) == trace", arguments: Fixtures.synthetic)
    func roundTrip(name: String) throws {
        let trace = try Fixtures.trace(name)
        let decoded = try Trace(jsonData: trace.jsonData(redactSensitive: false))
        #expect(decoded == trace)
    }

    @Test("Round trip of a recorded trace, including sub-second createdAt")
    func recordedRoundTrip() async throws {
        let start = ContinuousClock.now
        let recorder = TraceRecorder(
            metadata: TraceMetadata(
                createdAt: Date(timeIntervalSince1970: 1_795_000_000.75),
                app: AppInfo(name: "FIDOSims", version: "0.1.0", build: "1"),
                transport: .nfc, device: DeviceInfo(model: "iPhone16,2", os: "iOS 26.1"),
                cardLabel: "Lab card A", options: TraceOptions()
            ),
            connection: CardConnection(
                sessionStartedAt: start, cardDetectedAt: start + .milliseconds(1503),
                initialSelectedAID: try Hex.parse("A0000006472F0001")
            )
        )
        await recorder.record(
            RawExchange(
                command: try Hex.parse("00A4040008A0000006472F000100"),
                response: ResponseAPDU(data: Data("FIDO_2_0".utf8), sw: .success),
                startedAt: start + .microseconds(1_503_100), endedAt: start + .microseconds(1_515_500)
            ),
            commandIndex: await recorder.nextCommandIndex(), label: "SELECT_FIDO", sensitive: false
        )
        await recorder.end(reason: .completed, at: start + .microseconds(1_842_700))
        let trace = await recorder.trace

        #expect(try Trace(jsonData: trace.jsonData()) == trace)
    }

    @Test("Encodes hex uppercase without spaces and dates as ISO 8601")
    func encodingShape() throws {
        let trace = try Fixtures.trace("synthetic-fido2-getinfo-chained")
        let json = String(decoding: try trace.jsonData(), as: UTF8.self)
        #expect(json.contains(#""tx" : "00A4040008A0000006472F000100""#))
        #expect(json.contains(#""sw" : "9000""#))
        #expect(json.contains(#""createdAt" : "2026-11-19T00:00:00Z""#))
        #expect(json.contains(#""initialSelectedAID" : "A0000006472F0001""#))
        #expect(json.contains(#""type" : "sessionEnded""#))
    }

    @Test("Redacted JSON has null bytes, lengths and a redacted flag, and still decodes")
    func redactedJSON() throws {
        let trace = try Self.traceWithSensitiveExchange()
        let json = String(decoding: try trace.jsonData(), as: UTF8.self)
        #expect(json.contains(#""tx" : null"#))
        #expect(json.contains(#""rx" : null"#))
        #expect(json.contains(#""txLength" : 8"#))
        #expect(json.contains(#""rxLength" : 3"#))
        #expect(json.contains(#""redacted" : true"#))
        #expect(json.contains(#""sw" : "9000""#))
        #expect(!json.contains("DEADBEEF"))
        #expect(!json.contains("<redacted"))

        let decoded = try Trace(jsonData: Data(json.utf8))
        let exchange = try #require(decoded.exchanges.first)
        #expect(exchange.isRedacted)
        #expect(exchange.tx.count == 8)
        #expect(exchange.rx.count == 3)
        #expect(exchange.sw == .success)
        #expect(decoded == trace.redactingSensitive())

        let plain = String(decoding: try trace.jsonData(redactSensitive: false), as: UTF8.self)
        #expect(plain.contains("DEADBEEF"))
        #expect(!plain.contains("redacted"))
        #expect(!plain.contains("txLength"))
    }

    @Test("A redacted exchange with bytes, or without lengths, does not decode")
    func malformedRedaction() throws {
        let withBytes = Self.exchangeJSON(#""tx": "00", "rx": null, "txLength": 1, "rxLength": 0, "redacted": true"#)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ExchangeEvent.self, from: withBytes) }
        let withoutLength = Self.exchangeJSON(#""tx": null, "rx": null, "rxLength": 0, "redacted": true"#)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(ExchangeEvent.self, from: withoutLength) }
        let placeholder = Self.exchangeJSON(#""tx": "<redacted 1 bytes>", "rx": """#)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(ExchangeEvent.self, from: placeholder) }
    }

    @Test("Known end reasons encode as their documented string and round-trip", arguments: SessionEndReason.known)
    func knownReason(reason: SessionEndReason) throws {
        let data = try JSONEncoder().encode(reason)
        #expect(String(decoding: data, as: UTF8.self) == "\"\(reason.rawValue)\"")
        #expect(try JSONDecoder().decode(SessionEndReason.self, from: data) == reason)
    }

    @Test("An unknown end reason decodes as .unknown and encodes back unchanged")
    func unknownReason() throws {
        let decoded = try JSONDecoder().decode(SessionEndReason.self, from: Data(#""postSessionFailed""#.utf8))
        #expect(decoded == .unknown("postSessionFailed"))
        #expect(decoded.displayName == "postSessionFailed")
        #expect(String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self) == #""postSessionFailed""#)
        #expect(SessionEndReason(rawValue: "completed") == .completed)
    }

    private static func exchangeJSON(_ bytes: String) -> Data {
        Data(#"{"index": 1, "commandIndex": 1, "label": "X", \#(bytes), "sw": "9000", "tStart": 0, "tEnd": 1, "sensitive": true}"#.utf8)
    }

    static func traceWithSensitiveExchange() throws -> Trace {
        var trace = try MockScript.trace([.init(tx: "80100000DEADBEEF", rx: "010203", sw: "9000")])
        trace.events = trace.events.map { event in
            guard case var .exchange(exchange) = event else { return event }
            exchange.sensitive = true
            return .exchange(exchange)
        }
        return trace
    }
}
