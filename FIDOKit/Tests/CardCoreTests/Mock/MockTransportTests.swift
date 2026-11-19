import CardCore
import Foundation
import Testing

@Suite("MockTransport")
struct MockTransportTests {
    @Test("Replays a fixture with its recorded timings")
    func replay() async throws {
        let fixture = try Fixtures.trace("synthetic-fido2-getinfo-chained")
        let transport = try MockTransport(trace: fixture)
        let connection = try await transport.open(prompt: "")
        #expect(connection.initialSelectedAID == fixture.card.initialSelectedAID)
        #expect(connection.cardDetectedAt - connection.sessionStartedAt == .milliseconds(1500))

        for expected in fixture.exchanges {
            let exchange = try await transport.transmit(expected.tx)
            #expect(exchange.response == ResponseAPDU(data: expected.rx, sw: expected.sw))
            #expect(exchange.startedAt - connection.sessionStartedAt == .nanoseconds(expected.tStart))
            #expect(exchange.endedAt - exchange.startedAt == .nanoseconds(expected.rtt))
        }
        #expect(await transport.remainingExchanges == 0)
        await transport.close(errorMessage: nil)
    }

    @Test("Fails clearly when tx differs from the script")
    func mismatch() async throws {
        let transport = try MockTransport(trace: try Fixtures.trace("synthetic-u2f-only"))
        _ = try await transport.open(prompt: "")
        let actual = try Hex.parse("00A4040008A0000006472F000200")
        let error = await #expect(throws: MockTransportError.self) {
            try await transport.transmit(actual)
        }
        #expect(error == .unexpectedCommand(
            index: 1, label: "SELECT_FIDO", expected: try Hex.parse("00A4040008A0000006472F000100"), actual: actual
        ))
        let message = try #require(error?.localizedDescription)
        #expect(message.contains("Expected: 00 A4 04 00 08 A0 00 00 06 47 2F 00 01 00"))
        #expect(message.contains("Actual:   00 A4 04 00 08 A0 00 00 06 47 2F 00 02 00"))
    }

    @Test("Fails when the script is exhausted")
    func exhausted() async throws {
        let transport = try MockTransport(trace: try Fixtures.trace("synthetic-select-fail"))
        _ = try await transport.open(prompt: "")
        let select = try Hex.parse("00A4040008A0000006472F000100")
        _ = try await transport.transmit(select)
        await #expect(throws: MockTransportError.scriptExhausted(actual: select)) {
            try await transport.transmit(select)
        }
    }

    @Test("Requires an open session")
    func notOpen() async throws {
        let transport = try MockTransport(trace: try Fixtures.trace("synthetic-select-fail"))
        await #expect(throws: MockTransportError.notOpen) {
            try await transport.transmit(Data([0x00]))
        }
    }

    @Test("Refuses redacted fixtures")
    func redactedFixture() throws {
        let trace = try TraceCodingTests.traceWithSensitiveExchange().redactingSensitive()
        #expect(throws: MockTransportError.redactedFixture(index: 1)) {
            try MockTransport(trace: trace)
        }
    }

    @Test("Realtime mode waits for the recorded durations")
    func realtime() async throws {
        let trace = try MockScript.trace([.init(tx: "00", sw: "9000")])
        let transport = try MockTransport(trace: trace, realtime: true)
        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            _ = try await transport.open(prompt: "")
            _ = try await transport.transmit(Data([0x00]))
        }
        #expect(elapsed >= .milliseconds(101))
    }
}
