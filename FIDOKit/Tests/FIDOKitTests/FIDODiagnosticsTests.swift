import FIDOKit
import Foundation
import Testing

@Suite("FIDODiagnostics against MockTransport")
struct FIDODiagnosticsTests {
    private func options(for fixture: Trace) -> DiagnosticsOptions {
        DiagnosticsOptions(
            lengthForm: fixture.options.lengthForm,
            getResponseSupported: fixture.options.getResponseSupported,
            cardLabel: fixture.card.label,
            app: fixture.app,
            device: fixture.device
        )
    }

    /// Runs the fixture and checks that every exchange replays identically.
    private func replay(_ name: String, subdirectory: String = "synthetic") async throws -> (Trace, Trace) {
        let fixture = try FixtureFiles.trace(name, subdirectory: subdirectory)
        let transport = try MockTransport(trace: fixture)
        let trace = try await FIDODiagnostics.runSelectAndGetInfo(transport: transport, options: options(for: fixture))

        #expect(trace.exchanges == fixture.exchanges)
        #expect(trace.cardDetectedTime == fixture.cardDetectedTime)
        #expect(trace.card == fixture.card)
        #expect(trace.options == fixture.options)
        #expect(trace.transport == .mock)
        #expect(TraceMetrics(trace: trace) == TraceMetrics(trace: fixture))
        #expect(await transport.remainingExchanges == 0)
        return (trace, fixture)
    }

    @Test("(a) FIDO_2_0 card with a 61xx chain on GetInfo")
    func fido2Chained() async throws {
        let (trace, _) = try await replay("synthetic-fido2-getinfo-chained")
        #expect(trace.endReason == .completed)
        #expect(trace.exchanges.filter { $0.label == "GET_INFO" }.count == 4)
    }

    @Test("(b) U2F_V2-only card: GetInfo 6D00 is recorded as CTAP1-only")
    func u2fOnly() async throws {
        let (trace, _) = try await replay("synthetic-u2f-only")
        #expect(trace.endReason == .ctap1Only)
        #expect(trace.endReason?.displayName == "CTAP1-only card")
    }

    @Test("(c) SELECT failure with 6A82: recorded, GET_INFO skipped, trace returned")
    func selectFailure() async throws {
        let (trace, _) = try await replay("synthetic-select-fail")
        #expect(trace.endReason == .selectFailed)
        #expect(trace.exchanges.map(\.label) == ["SELECT_FIDO"])
    }

    @Test("PC/SC recorder sample (simulated card) decodes and replays")
    func pcscSample() async throws {
        let (trace, fixture) = try await replay("synthetic-pcsc-recorder", subdirectory: "synthetic")
        #expect(fixture.transport == .pcsc)
        #expect(trace.endReason == .completed)
    }

    @Test("Reports progress in order")
    func progress() async throws {
        let fixture = try FixtureFiles.trace("synthetic-u2f-only")
        let log = ProgressLog()
        _ = try await FIDODiagnostics.runSelectAndGetInfo(
            transport: try MockTransport(trace: fixture), options: options(for: fixture), progress: log.callback()
        )
        try await Task.sleep(for: .milliseconds(50))
        let events = await log.events
        #expect(events.first == .waitingForCard)
        #expect(events.last == .finished(.ctap1Only))
        #expect(events.contains(.exchanging(label: "GET_INFO")))
    }

    @Test("A mismatching card fails with the partial trace")
    func failureKeepsTrace() async throws {
        let fixture = try FixtureFiles.trace("synthetic-fido2-getinfo-chained")
        var options = options(for: fixture)
        options.getResponseSupported = true // P1 = 80 no longer matches the script
        let error = await #expect(throws: DiagnosticsFailure.self) {
            try await FIDODiagnostics.runSelectAndGetInfo(transport: try MockTransport(trace: fixture), options: options)
        }
        let failure = try #require(error)
        #expect(failure.underlying is MockTransportError)
        #expect(!failure.isCancellation)
        #expect(failure.trace.exchanges.count == 1)
        #expect(failure.trace.endReason == .error)
    }

    @Test("Cancellation ends the trace as cancelled")
    func cancellation() async throws {
        let fixture = try FixtureFiles.trace("synthetic-fido2-getinfo-chained")
        let transport = try MockTransport(trace: fixture, realtime: true)
        let options = options(for: fixture)
        let task = Task {
            try await FIDODiagnostics.runSelectAndGetInfo(transport: transport, options: options)
        }
        try await Task.sleep(for: .milliseconds(1505))
        task.cancel()
        let failure = try #require(await #expect(throws: DiagnosticsFailure.self) { try await task.value })
        #expect(failure.isCancellation)
        #expect(failure.trace.endReason == .cancelled)
        #expect(failure.trace.exchanges.count < fixture.exchanges.count)
    }
}
