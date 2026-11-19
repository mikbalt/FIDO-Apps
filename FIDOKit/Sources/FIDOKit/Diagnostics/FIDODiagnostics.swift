import Foundation

/// Engineering scenarios that exercise a card end to end.
public enum FIDODiagnostics {
    public static let prompt = "Hold the card near the top of the iPhone"

    /// open → `SELECT_FIDO` → `GET_INFO` → close.
    ///
    /// Card-level outcomes are recorded in the trace's `sessionEnded` reason, not thrown:
    /// - `selectFailed`: SELECT did not return 9000 with a known version string; GET_INFO is skipped.
    /// - `ctap1Only`: GetInfo returned `6D00`.
    /// - `getInfoFailed`: GetInfo returned another SW, or a non-zero CTAP status byte.
    ///
    /// - Throws: Errors from `open` (no card was connected, so there is no trace), or a
    ///   `DiagnosticsFailure` with the partial trace for errors and cancellation after connecting.
    public static func runSelectAndGetInfo(
        transport: any CardTransport,
        options: DiagnosticsOptions = DiagnosticsOptions(),
        progress: @escaping @Sendable (DiagnosticsProgress) -> Void = { _ in }
    ) async throws -> Trace {
        progress(.waitingForCard)
        let connection = try await transport.open(prompt: prompt)
        progress(.cardDetected)

        let channelOptions = options.channelOptions
        let recorder = TraceRecorder(
            metadata: TraceMetadata(
                app: options.app, transport: transport.kind, device: options.device,
                cardLabel: options.cardLabel, options: channelOptions.traceOptions
            ),
            connection: connection
        )
        let channel = ISO7816Channel(transport: transport, recorder: recorder, options: channelOptions)
        let statusForwarding = Task {
            for await status in channel.statusUpdates {
                progress(.statusUpdate(status))
            }
        }
        defer { statusForwarding.cancel() }

        do {
            let reason = try await selectAndGetInfo(channel, progress: progress)
            await transport.close(errorMessage: nil)
            await recorder.end(reason: reason)
            progress(.finished(reason))
            return await recorder.trace
        } catch {
            let isCancellation = DiagnosticsFailure.isCancellation(error)
            let reason: SessionEndReason = isCancellation ? .cancelled : .error
            await transport.close(errorMessage: isCancellation ? nil : error.localizedDescription)
            await recorder.end(reason: reason)
            progress(.finished(reason))
            throw DiagnosticsFailure(underlying: error, trace: await recorder.trace)
        }
    }

    private static func selectAndGetInfo(
        _ channel: ISO7816Channel, progress: @Sendable (DiagnosticsProgress) -> Void
    ) async throws -> SessionEndReason {
        progress(.exchanging(label: "SELECT_FIDO"))
        do {
            _ = try await channel.selectFIDO()
        } catch ChannelError.unexpectedStatus, ChannelError.unknownAppletVersion {
            return .selectFailed
        }

        progress(.exchanging(label: "GET_INFO"))
        let response = try await channel.send(channel.nfcctapMsg(Data([0x04])), label: "GET_INFO")
        if response.sw == .insNotSupported {
            return .ctap1Only
        }
        // First byte is the CTAP status (00 = OK); the rest is CBOR, decoded in brief 02.
        guard response.sw.isSuccess, response.data.first == 0x00 else {
            return .getInfoFailed
        }
        return .completed
    }
}
