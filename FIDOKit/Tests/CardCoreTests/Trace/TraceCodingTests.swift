import CardCore
import Foundation
import Testing

@Suite("Trace JSON")
struct TraceCodingTests {
    @Test("All synthetic fixtures decode", arguments: Fixtures.synthetic)
    func fixturesDecode(name: String) throws {
        let trace = try Fixtures.trace(name)
        #expect(trace.schemaVersion == 1)
        #expect(!trace.exchanges.isEmpty)
        #expect(trace.sessionStartedTime == 0)
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
