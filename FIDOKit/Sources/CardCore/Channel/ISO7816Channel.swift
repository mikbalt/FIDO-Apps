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
    /// polling. Every physical exchange is recorded under the same command index and label, followed by one
    /// `command` event. Cancellation is checked between exchanges; exchanges already done stay in the trace.
    public func send(_ command: CommandAPDU, label: String, sensitive: Bool = false) async throws -> ResponseAPDU {
        try await sendLogical(command, label: label, sensitive: sensitive, form: options.lengthForm).response
    }

    /// SELECTs the FIDO applet and returns its version string (`U2F_V2` or `FIDO_2_0`).
    ///
    /// Always sent in short form. Throws `ChannelError.unexpectedStatus` for a status other than `9000`,
    /// and `ChannelError.unknownAppletVersion` for an unknown version string.
    public func selectFIDO() async throws -> String {
        let response = try await sendLogical(.selectFIDO, label: "SELECT_FIDO", sensitive: false, form: .short).response
        guard response.sw.isSuccess else { throw ChannelError.unexpectedStatus(response.sw) }
        let version = String(decoding: response.data, as: UTF8.self)
        guard FIDOApplet.knownVersions.contains(version) else { throw ChannelError.unknownAppletVersion(version) }
        return version
    }

    /// NFCCTAP_MSG carrying a CTAP command: CLA `80`, INS `10`, P1 `80` or `00`, P2 `00`, max Le for the form.
    public func nfcctapMsg(_ payload: Data, getResponseSupported: Bool? = nil) -> CommandAPDU {
        CommandAPDU(
            cla: 0x80, ins: 0x10, p1: (getResponseSupported ?? options.getResponseSupported) ? 0x80 : 0x00, p2: 0x00,
            data: payload, le: options.lengthForm.maxLe
        )
    }

    /// Sends a CTAP request (command byte ‖ CBOR) in NFCCTAP_MSG as one logical command.
    ///
    /// With `getResponseSupported` (P1 = `80`), a card that answers `6A86` or `6B00` gets the same command
    /// once more with P1 = `00`, inside the same logical command, and a `P1_FALLBACK` warning is recorded.
    /// The caller keeps P1 = `00` for the rest of the session when `usedP1Fallback` is set.
    public func sendNFCCTAP(
        _ request: Data, label: String, sensitive: Bool = false, getResponseSupported: Bool
    ) async throws -> NFCCTAPResponse {
        try await sendLogical(
            nfcctapMsg(request, getResponseSupported: getResponseSupported), label: label, sensitive: sensitive,
            form: options.lengthForm, ctapCommand: request.first, allowsP1Fallback: getResponseSupported
        )
    }

    // MARK: - Logical command

    private func sendLogical(
        _ command: CommandAPDU, label: String, sensitive: Bool, form: LengthForm,
        ctapCommand: UInt8? = nil, allowsP1Fallback: Bool = false
    ) async throws -> NFCCTAPResponse {
        let commandIndex = await recorder.nextCommandIndex()
        var recorded: [ExchangeEvent] = []
        var lastEndedAt: ContinuousClock.Instant?

        func exchange(_ apdu: CommandAPDU, form: LengthForm) async throws -> ResponseAPDU {
            try Task.checkCancellation()
            let raw = try await transport.transmit(try apdu.encoded(form))
            recorded.append(await recorder.record(raw, commandIndex: commandIndex, label: label, sensitive: sensitive))
            lastEndedAt = raw.endedAt
            return raw.response
        }

        func recordCommand(sw: StatusWord, data: Data) async {
            guard let first = recorded.first, let last = recorded.last else { return }
            await recorder.record(CommandEvent(
                commandIndex: commandIndex, label: label, ctapCommand: ctapCommand,
                ctapStatus: ctapCommand != nil && sw.isSuccess ? data.first : nil,
                sw: sw, tStart: first.tStart, tEnd: last.tEnd, exchanges: recorded.map(\.index)
            ))
        }

        func expand(_ command: CommandAPDU) async throws -> ResponseAPDU {
            // 1–2. Encoding and short-form command chaining.
            var last = command
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
            var response = try await exchange(last, form: form)

            // 4. Wrong Le: resend once with the exact length.
            if response.sw.sw1 == 0x6C {
                last.le = response.sw.sw2 == 0 ? 256 : Int(response.sw.sw2)
                response = try await exchange(last, form: form)
            }

            // An extended-form command should get all its data at once; 61xx means the card chained anyway.
            if form == .extended, response.sw.sw1 == 0x61 {
                await recorder.recordWarning(
                    .extendedFormChained,
                    "\(label): the card answered an extended-form command with SW \(response.sw.hex).",
                    at: lastEndedAt ?? .now
                )
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
                    let status = NFCCTAPStatus(statusByte: response.data.first)
                    await recorder.recordStatus(status, at: lastEndedAt ?? .now)
                    statusContinuation.yield(status)
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

        do {
            var usedP1Fallback = false
            var response: ResponseAPDU
            do {
                response = try await expand(command)
            } catch let ChannelError.chainingFailed(chunk, sw) where allowsP1Fallback && chunk == 1 && Self.rejectsP1(sw) {
                // A chained NFCCTAP_MSG is rejected on its first chunk: same P1 fallback as below.
                response = ResponseAPDU(data: Data(), sw: sw)
            }
            if allowsP1Fallback, command.p1 == 0x80, Self.rejectsP1(response.sw) {
                await recorder.recordWarning(
                    .p1Fallback,
                    "\(label): the card answered NFCCTAP_MSG with P1 = 80 with SW \(response.sw.hex); "
                        + "resent with P1 = 00, which is kept for the rest of the session.",
                    at: lastEndedAt ?? .now
                )
                var retry = command
                retry.p1 = 0x00
                response = try await expand(retry)
                usedP1Fallback = true
            }
            await recordCommand(sw: response.sw, data: response.data)
            return NFCCTAPResponse(response: response, usedP1Fallback: usedP1Fallback)
        } catch {
            if let last = recorded.last {
                await recordCommand(sw: last.sw, data: Data())
            }
            throw error
        }
    }

    /// `6A86` (incorrect P1-P2) and `6B00` (wrong P1-P2): how cards refuse NFCCTAP_MSG with P1 = `80`.
    private static func rejectsP1(_ sw: StatusWord) -> Bool {
        sw == .incorrectP1P2 || sw == .wrongP1P2
    }

    private static func chunks(of data: Data, size: Int) -> [Data] {
        stride(from: 0, to: data.count, by: size).map { offset in
            let start = data.startIndex + offset
            return Data(data[start..<min(start + size, data.endIndex)])
        }
    }
}
