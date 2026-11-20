import CardCore
@testable import CTAP
import Foundation
import Testing

@Suite("Decoded view model")
struct TraceCommandDecoderTests {
    @Test("One decoded command per logical command, with the GetInfo response reassembled from 61xx")
    func getInfoFixture() throws {
        let trace = try CTAPFixtures.trace("synthetic-getinfo-full")
        let commands = TraceCommandDecoder.commands(in: trace)
        #expect(commands.map(\.label) == ["SELECT_FIDO", "GET_INFO"])
        #expect(commands.map(\.summary) == ["FIDO applet selected (FIDO_2_0)", "Capabilities received"])
        #expect(commands[0].request == nil)
        #expect(commands[1].request == nil) // GetInfo has no parameters
        #expect(commands[1].response?[5] == 1200)
        #expect(TraceCommandDecoder.getInfo(in: trace)?.minPINLength == 6)
    }

    @Test("Failures are summarised by SW or CTAP status name")
    func failures() throws {
        let select = TraceCommandDecoder.commands(in: try CTAPFixtures.trace("synthetic-select-fail"))
        #expect(select.first?.summary == "SW 6A82 File or application not found")
        #expect(select.first?.succeeded == false)

        var trace = try CTAPFixtures.trace("synthetic-getinfo-full")
        trace.events = trace.events.map { event in
            guard case var .exchange(exchange) = event, exchange.index == 3 else { return event }
            exchange.rx = Data([0x31])
            exchange.ctapStatus = 0x31
            return .exchange(exchange)
        }
        #expect(TraceCommandDecoder.commands(in: trace).last?.summary == "Refused: CTAP2_ERR_PIN_INVALID")
        #expect(TraceCommandDecoder.getInfo(in: trace) == nil)
    }

    @Test("Requests decode from short and extended NFCCTAP_MSG; sensitive commands are never decoded")
    func requests() throws {
        #expect(TraceCommandDecoder.nfcctapDataForTests(try Hex.parse("8010000006" + "06A201020201" + "00")) == (try Hex.parse("06A201020201")))
        #expect(TraceCommandDecoder.nfcctapDataForTests(try Hex.parse("80100000000002" + "0604" + "0000")) == (try Hex.parse("0604")))
        #expect(TraceCommandDecoder.nfcctapDataForTests(try Hex.parse("00A4040008A0000006472F000100")) == nil)

        var trace = try CTAPFixtures.trace("synthetic-getinfo-full")
        trace.events = trace.events.map { event in
            guard case var .exchange(exchange) = event, exchange.label == "GET_INFO" else { return event }
            exchange.sensitive = true
            return .exchange(exchange)
        }
        let getInfo = try #require(TraceCommandDecoder.commands(in: trace).last)
        #expect(getInfo.sensitive)
        #expect(getInfo.response == nil)
    }
}

extension TraceCommandDecoder {
    static func nfcctapDataForTests(_ tx: Data) -> Data? { nfcctapData(tx) }
}
