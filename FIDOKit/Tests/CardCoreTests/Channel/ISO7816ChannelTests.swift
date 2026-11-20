import CardCore
import Foundation
import Testing

@Suite("ISO7816Channel")
struct ISO7816ChannelTests {
    private typealias Step = MockScript.Step

    private func makeChannel(
        _ steps: [Step], options: ChannelOptions = ChannelOptions()
    ) async throws -> (ISO7816Channel, MockTransport) {
        let transport = try MockScript.transport(steps)
        return (try await makeChannel(transport: transport, options: options), transport)
    }

    private func makeChannel(transport: any CardTransport, options: ChannelOptions = ChannelOptions()) async throws -> ISO7816Channel {
        let connection = try await transport.open(prompt: "")
        let recorder = TraceRecorder(
            metadata: TraceMetadata(transport: transport.kind, cardLabel: "Test", options: options.traceOptions),
            connection: connection
        )
        return ISO7816Channel(transport: transport, recorder: recorder, options: options)
    }

    private let getInfo = CommandAPDU(cla: 0x80, ins: 0x10, p1: 0, p2: 0, data: Data([0x04]), le: 256)

    @Test("Three 61xx responses: data concatenated in order, 4 exchanges under one command")
    func getResponseChain() async throws {
        let (channel, transport) = try await makeChannel([
            Step(tx: "80100000010400", rx: "0102", sw: "6102"),
            Step(tx: "00C0000002", rx: "0304", sw: "6102"),
            Step(tx: "00C0000002", rx: "0506", sw: "6101"),
            Step(tx: "00C0000001", rx: "07", sw: "9000"),
        ])
        let response = try await channel.send(getInfo, label: "GET_INFO")

        #expect(response == ResponseAPDU(data: Data([1, 2, 3, 4, 5, 6, 7]), sw: .success))
        let exchanges = await channel.recorder.trace.exchanges
        #expect(exchanges.count == 4)
        #expect(exchanges.map(\.index) == [1, 2, 3, 4])
        #expect(exchanges.allSatisfy { $0.commandIndex == 1 && $0.label == "GET_INFO" })
        #expect(await transport.remainingExchanges == 0)
    }

    @Test("61 00 triggers GET RESPONSE with Le 00")
    func getResponse256() async throws {
        let (channel, _) = try await makeChannel([
            Step(tx: "80100000010400", rx: "AA", sw: "6100"),
            Step(tx: "00C0000000", rx: "BB", sw: "9000"),
        ])
        let response = try await channel.send(getInfo, label: "GET_INFO")
        #expect(response.data == Data([0xAA, 0xBB]))
    }

    @Test("6Cxx triggers exactly one resend with the corrected Le")
    func wrongLe() async throws {
        let (channel, transport) = try await makeChannel([
            Step(tx: "00B0000000", sw: "6C10"),
            Step(tx: "00B0000010", sw: "6C08"),
            Step(tx: "00B0000008", sw: "9000"),
        ])
        let response = try await channel.send(CommandAPDU(cla: 0, ins: 0xB0, p1: 0, p2: 0, le: 256), label: "READ")

        #expect(response.sw == StatusWord(rawValue: 0x6C08))
        #expect(await channel.recorder.trace.exchanges.count == 2)
        #expect(await transport.remainingExchanges == 1)
    }

    @Test("600-byte payload in short form: 3 chunks with CLA 90, 90, 80; only the last carries Le")
    func commandChaining() async throws {
        let payload = Data((0..<600).map { UInt8(truncatingIfNeeded: $0) })
        let chunk1 = Hex.compact(payload.prefix(255))
        let chunk2 = Hex.compact(payload.dropFirst(255).prefix(255))
        let chunk3 = Hex.compact(payload.suffix(90))
        let (channel, _) = try await makeChannel([
            Step(tx: "901000" + "00FF" + chunk1, sw: "9000"),
            Step(tx: "901000" + "00FF" + chunk2, sw: "9000"),
            Step(tx: "801000" + "005A" + chunk3 + "00", rx: "00", sw: "9000"),
        ])
        let response = try await channel.send(channel.nfcctapMsg(payload), label: "CTAP")

        #expect(response.sw.isSuccess)
        let exchanges = await channel.recorder.trace.exchanges
        #expect(exchanges.map { $0.tx.first } == [0x90, 0x90, 0x80])
    }

    @Test("A non-9000 intermediate chunk response throws")
    func chainingFailure() async throws {
        let payload = Data(repeating: 0x11, count: 600)
        let (channel, _) = try await makeChannel([
            Step(tx: "90100000FF" + Hex.compact(payload.prefix(255)), sw: "9000"),
            Step(tx: "90100000FF" + Hex.compact(payload.prefix(255)), sw: "6700"),
        ])
        await #expect(throws: ChannelError.chainingFailed(chunk: 2, sw: .wrongLength)) {
            try await channel.send(channel.nfcctapMsg(payload), label: "CTAP")
        }
        #expect(await channel.recorder.trace.exchanges.count == 2)
    }

    @Test("Extended form sends large payloads without chaining")
    func extendedNoChaining() async throws {
        let payload = Data(repeating: 0x22, count: 300)
        let (channel, _) = try await makeChannel(
            [Step(tx: "80100000" + "00012C" + Hex.compact(payload) + "0000", sw: "9000")],
            options: ChannelOptions(lengthForm: .extended)
        )
        _ = try await channel.send(channel.nfcctapMsg(payload), label: "CTAP")
        #expect(await channel.recorder.trace.exchanges.count == 1)
    }

    @Test("9100 twice, then 9000: exactly 2 GETRESPONSE polls, with status updates")
    func statusUpdates() async throws {
        let (channel, transport) = try await makeChannel([
            Step(tx: "80100000010400", rx: "01", sw: "9100"),
            Step(tx: "8011000000", rx: "02", sw: "9100"),
            Step(tx: "8011000000", rx: "00AA", sw: "9000"),
        ])
        let response = try await channel.send(getInfo, label: "GET_INFO")
        channel.finishStatusUpdates()

        #expect(response == ResponseAPDU(data: Data([0x00, 0xAA]), sw: .success))
        let polls = await channel.recorder.trace.exchanges.filter { $0.tx == (try? Hex.parse("8011000000")) }
        #expect(polls.count == 2)
        #expect(await transport.remainingExchanges == 0)

        var updates: [NFCCTAPStatus] = []
        for await update in channel.statusUpdates {
            updates.append(update)
        }
        #expect(updates == [.processing, .userPresenceNeeded])
    }

    @Test("Endless 9100 ends in a timeout error")
    func statusTimeout() async throws {
        let steps = [Step(tx: "80100000010400", rx: "01", sw: "9100")]
            + Array(repeating: Step(tx: "8011000000", rx: "01", sw: "9100"), count: 500)
        let (channel, _) = try await makeChannel(
            steps,
            options: ChannelOptions(statusPollInterval: .milliseconds(2), statusUpdateTimeout: .milliseconds(40))
        )
        await #expect(throws: ChannelError.statusUpdateTimeout) {
            try await channel.send(getInfo, label: "GET_INFO")
        }
    }

    @Test("Cancelling mid-chain throws CancellationError and keeps completed exchanges")
    func cancellation() async throws {
        let inner = try MockScript.transport([
            Step(tx: "80100000010400", rx: "01", sw: "6101"),
            Step(tx: "00C0000001", rx: "02", sw: "6101"),
            Step(tx: "00C0000001", rx: "03", sw: "9000"),
        ])
        let channel = try await makeChannel(transport: CancellingTransport(inner: inner, cancelAfter: 2))
        let command = getInfo

        let task = Task { try await channel.send(command, label: "GET_INFO") }
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        let exchanges = await channel.recorder.trace.exchanges
        #expect(exchanges.count == 2)
        #expect(await inner.remainingExchanges == 1)
    }

    @Test("selectFIDO sends the fixed SELECT and returns the version")
    func selectFIDO() async throws {
        let (channel, _) = try await makeChannel(
            [Step(tx: "00A4040008A0000006472F000100", rx: "4649444F5F325F30", sw: "9000")],
            options: ChannelOptions(lengthForm: .extended)
        )
        #expect(try await channel.selectFIDO() == "FIDO_2_0")
        #expect(await channel.recorder.trace.exchanges.first?.label == "SELECT_FIDO")
    }

    @Test("selectFIDO throws on failure status and unknown versions")
    func selectFIDOFailures() async throws {
        let (failing, _) = try await makeChannel([Step(tx: "00A4040008A0000006472F000100", sw: "6A82")])
        await #expect(throws: ChannelError.unexpectedStatus(.fileNotFound)) {
            try await failing.selectFIDO()
        }
        let (unknown, _) = try await makeChannel([Step(tx: "00A4040008A0000006472F000100", rx: "4142", sw: "9000")])
        await #expect(throws: ChannelError.unknownAppletVersion("AB")) {
            try await unknown.selectFIDO()
        }
    }

    @Test("nfcctapMsg: P1 follows getResponseSupported and Le is the form's maximum")
    func nfcctapMsg() async throws {
        #expect(!ChannelOptions().getResponseSupported)
        let (short, _) = try await makeChannel([])
        #expect(try short.nfcctapMsg(Data([0x04])).encoded(.short) == Hex.parse("80100000010400"))

        let (extended, _) = try await makeChannel([], options: ChannelOptions(lengthForm: .extended, getResponseSupported: true))
        let message = extended.nfcctapMsg(Data([0x04]))
        #expect(message.p1 == 0x80)
        #expect(message.le == 65536)
        #expect(try message.encoded(.extended) == Hex.parse("80108000000001040000"))
    }

    // MARK: - v2 warnings

    @Test("61xx in answer to an extended-form command records EXTENDED_FORM_CHAINED")
    func extendedFormChained() async throws {
        let (channel, _) = try await makeChannel(
            [
                Step(tx: "8010000000000104" + "0000", rx: "00", sw: "6101"),
                Step(tx: "00C0000001", rx: "A0", sw: "9000"),
            ],
            options: ChannelOptions(lengthForm: .extended)
        )
        let response = try await channel.send(channel.nfcctapMsg(Data([0x04])), label: "GET_INFO")
        #expect(response.data == Data([0x00, 0xA0]))
        let warnings = await channel.recorder.trace.warnings
        #expect(warnings.map(\.code) == [.extendedFormChained])
    }

    @Test("61xx in short form is not a warning")
    func shortFormChainNoWarning() async throws {
        let (channel, _) = try await makeChannel([
            Step(tx: "80100000010400", rx: "00", sw: "6101"),
            Step(tx: "00C0000001", rx: "A0", sw: "9000"),
        ])
        _ = try await channel.send(getInfo, label: "GET_INFO")
        #expect(await channel.recorder.trace.warnings.isEmpty)
    }
}
