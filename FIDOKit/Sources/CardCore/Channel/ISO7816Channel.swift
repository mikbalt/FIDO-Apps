import Foundation

/// Sends logical commands over a `CardTransport`, expanding each into the physical exchanges it needs,
/// and records every exchange in a `TraceRecorder`.
public final class ISO7816Channel: Sendable {
    public let transport: any CardTransport
    public let recorder: TraceRecorder
    public let options: ChannelOptions
    /// NFCCTAP status updates (SW `9100`), so a UI can ask the user to keep the card in place.
    public let statusUpdates: AsyncStream<NFCCTAPStatus>
    private let statusContinuation: AsyncStream<NFCCTAPStatus>.Continuation
    private let clock = ContinuousClock()

    public init(transport: any CardTransport, recorder: TraceRecorder, options: ChannelOptions = ChannelOptions()) {
        self.transport = transport
        self.recorder = recorder
        self.options = options
        (statusUpdates, statusContinuation) = AsyncStream.makeStream(of: NFCCTAPStatus.self)
    }

    deinit {
        statusContinuation.finish()
    }

    /// Ends `statusUpdates`.
    public func finishStatusUpdates() {
        statusContinuation.finish()
    }

    /// Sends one logical command and returns its complete response.
    ///
    /// Handles short-form command chaining, `61xx` GET RESPONSE, one `6Cxx` resend and `9100` NFCCTAP
    /// polling. Every physical exchange is recorded under the same command index and label. Cancellation
    /// is checked between exchanges; exchanges already done stay in the trace.
    public func send(_ command: CommandAPDU, label: String, sensitive: Bool = false) async throws -> ResponseAPDU {
        try await send(command, label: label, sensitive: sensitive, form: options.lengthForm)
    }

    /// SELECTs the FIDO applet and returns its version string (`U2F_V2` or `FIDO_2_0`).
    ///
    /// Always sent in short form. Throws `ChannelError.unexpectedStatus` for a status other than `9000`,
    /// and `ChannelError.unknownAppletVersion` for an unknown version string.
    public func selectFIDO() async throws -> String {
        let response = try await send(.selectFIDO, label: "SELECT_FIDO", sensitive: false, form: .short)
        guard response.sw.isSuccess else { throw ChannelError.unexpectedStatus(response.sw) }
        let version = String(decoding: response.data, as: UTF8.self)
        guard FIDOApplet.knownVersions.contains(version) else { throw ChannelError.unknownAppletVersion(version) }
        return version
    }

    /// NFCCTAP_MSG carrying a CTAP command: CLA `80`, INS `10`, P1 `80` or `00`, P2 `00`, max Le for the form.
    public func nfcctapMsg(_ payload: Data) -> CommandAPDU {
        CommandAPDU(
            cla: 0x80, ins: 0x10, p1: options.getResponseSupported ? 0x80 : 0x00, p2: 0x00,
            data: payload, le: options.lengthForm.maxLe
        )
    }

    // MARK: - Logical command

    private func send(
        _ command: CommandAPDU, label: String, sensitive: Bool, form: LengthForm
    ) async throws -> ResponseAPDU {
        let commandIndex = await recorder.nextCommandIndex()

        func exchange(_ apdu: CommandAPDU, form: LengthForm) async throws -> ResponseAPDU {
            try Task.checkCancellation()
            let raw = try await transport.transmit(try apdu.encoded(form))
            await recorder.record(raw, commandIndex: commandIndex, label: label, sensitive: sensitive)
            return raw.response
        }

        // 1–2. Encoding and short-form command chaining.
        var last = command
        var response: ResponseAPDU
        if form == .short, command.data.count > LengthForm.short.maxLc {
            let chunks = Self.chunks(of: command.data, size: LengthForm.short.maxLc)
            for (offset, chunk) in chunks.dropLast().enumerated() {
                let intermediate = CommandAPDU(
                    cla: command.cla | 0x10, ins: command.ins, p1: command.p1, p2: command.p2, data: chunk
                )
                let reply = try await exchange(intermediate, form: form)
                guard reply.sw.isSuccess else {
                    throw ChannelError.chainingFailed(chunk: offset + 1, sw: reply.sw)
                }
            }
            last.data = chunks[chunks.count - 1]
        }
        response = try await exchange(last, form: form)

        // 4. Wrong Le: resend once with the exact length.
        if response.sw.sw1 == 0x6C {
            last.le = response.sw.sw2 == 0 ? 256 : Int(response.sw.sw2)
            response = try await exchange(last, form: form)
        }

        // 3 and 5. Collect GET RESPONSE data and follow NFCCTAP status updates until a final SW.
        // Both follow-up commands are always short form, whatever `form` is (docs/trace-format.md).
        var data = Data()
        var statusDeadline: ContinuousClock.Instant?
        while true {
            if response.sw.sw1 == 0x61 {
                data.append(response.data)
                let le = response.sw.sw2 == 0 ? 256 : Int(response.sw.sw2)
                response = try await exchange(.getResponse(le: le), form: .short)
            } else if response.sw == .nfcctapStatusUpdate {
                statusContinuation.yield(NFCCTAPStatus(statusByte: response.data.first))
                let deadline = statusDeadline ?? clock.now + options.statusUpdateTimeout
                statusDeadline = deadline
                if options.statusPollInterval > .zero {
                    try await clock.sleep(for: options.statusPollInterval)
                }
                guard clock.now < deadline else { throw ChannelError.statusUpdateTimeout }
                response = try await exchange(.nfcctapGetResponse, form: .short)
            } else {
                break
            }
        }
        data.append(response.data)
        return ResponseAPDU(data: data, sw: response.sw)
    }

    private static func chunks(of data: Data, size: Int) -> [Data] {
        stride(from: 0, to: data.count, by: size).map { offset in
            let start = data.startIndex + offset
            return Data(data[start..<min(start + size, data.endIndex)])
        }
    }
}
