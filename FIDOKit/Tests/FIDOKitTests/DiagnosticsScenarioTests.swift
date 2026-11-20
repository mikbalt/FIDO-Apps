import FIDOKit
import FIDOTestSupport
import Foundation
import Testing

@Suite("FIDOSimulator.diagnostics against MockTransport")
struct DiagnosticsScenarioTests {
    private func simulator(_ fixture: Trace, transport: any CardTransport) -> FIDOSimulator {
        FIDOSimulator(transport: transport, configuration: FIDOSimConfiguration(
            lengthForm: fixture.options.lengthForm, getResponseSupported: fixture.options.getResponseSupported,
            cardLabel: fixture.card.label, app: fixture.app, device: fixture.device
        ))
    }

    /// Runs the fixture and checks that every exchange replays identically.
    private func replay(_ name: String) async throws -> (ScenarioResult<AuthenticatorInfo>, Trace) {
        let fixture = try FixtureFiles.trace(name)
        let transport = try MockTransport(trace: fixture)
        let result = await simulator(fixture, transport: transport).diagnostics { _ in }
        let trace = result.trace

        #expect(trace.exchanges.map(\.tx) == fixture.exchanges.map(\.tx))
        #expect(trace.exchanges.map(\.rx) == fixture.exchanges.map(\.rx))
        #expect(trace.exchanges.map(\.sw) == fixture.exchanges.map(\.sw))
        #expect(trace.cardDetectedTime == fixture.cardDetectedTime)
        #expect(trace.card.label == fixture.card.label)
        #expect(trace.options == fixture.options)
        #expect(trace.transport == .mock)
        #expect(trace.scenario == .diagnostics)
        #expect(TraceMetrics(trace: trace).apduTotal == TraceMetrics(trace: fixture).apduTotal)
        #expect(TraceMetrics(trace: trace).sessionTotal == TraceMetrics(trace: fixture).sessionTotal)
        #expect(await transport.remainingExchanges == 0)
        return (result, fixture)
    }

    @Test("FIDO_2_0 card with a 61xx chain on GetInfo")
    func fido2Chained() async throws {
        let (result, _) = try await replay("synthetic-fido2-getinfo-chained")
        #expect(result.error == nil)
        #expect(result.value?.versions == ["U2F_V2", "FIDO_2_0"])
        #expect(result.trace.outcome == .success)
        #expect(result.trace.endReason == .completed)
        #expect(result.trace.exchanges.last?.ctapStatus == 0x00)
    }

    @Test("The full synthetic GetInfo decodes and fills the card metadata")
    func fullGetInfo() async throws {
        let (result, fixture) = try await replay("synthetic-getinfo-full")
        let info = try #require(result.value)
        #expect(info.minPINLength == 6)
        #expect(info.otherEntries.contains { $0.key == 0x30 })
        #expect(result.trace.card.aaguid == fixture.card.aaguid)
        #expect(result.trace.card.versions == fixture.card.versions)
        #expect(result.trace.card.firmwareVersion == 66051)
    }

    @Test("U2F_V2-only card: GetInfo 6D00 is recorded as CTAP1-only")
    func u2fOnly() async throws {
        let (result, _) = try await replay("synthetic-u2f-only")
        #expect(result.value == nil)
        #expect(result.trace.endReason == .ctap1Only)
        #expect(result.error?.domain == .iso7816)
        #expect(result.error?.code == "6D00")
        #expect(result.trace.outcome?.status == .failure)
    }

    @Test("SELECT failure with 6A82: recorded, GET_INFO skipped, trace returned")
    func selectFailure() async throws {
        let (result, _) = try await replay("synthetic-select-fail")
        #expect(result.trace.endReason == .selectFailed)
        #expect(result.trace.exchanges.map(\.label) == ["SELECT_FIDO"])
        #expect(result.error?.name == "FILE_NOT_FOUND")
    }

    @Test("PC/SC recorder sample (simulated card) decodes and replays")
    func pcscSample() async throws {
        let (result, fixture) = try await replay("synthetic-pcsc-recorder")
        #expect(fixture.transport == .pcsc)
        #expect(result.trace.endReason == .completed)
    }

    @Test("Reports steps in order")
    func progress() async throws {
        let fixture = try FixtureFiles.trace("synthetic-fido2-getinfo-chained")
        let log = ProgressLog()
        _ = await simulator(fixture, transport: try MockTransport(trace: fixture)).diagnostics(progress: log.callback())
        #expect(log.events == [.waitingForCard, .cardDetected, .executing("SELECT_FIDO"), .executing("GET_INFO"), .completed])
    }

    @Test("A mismatching card fails with the partial trace")
    func failureKeepsTrace() async throws {
        let fixture = try FixtureFiles.trace("synthetic-fido2-getinfo-chained")
        let simulator = FIDOSimulator(transport: try MockTransport(trace: fixture), configuration: FIDOSimConfiguration(
            getResponseSupported: true // P1 = 80 no longer matches the script
        ))
        let result = await simulator.diagnostics { _ in }
        #expect(result.error?.domain == .internal)
        #expect(result.trace.exchanges.count == 1)
        #expect(result.trace.endReason == .error)
        #expect(result.trace.outcome?.status == .failure)
    }

    @Test("Task cancellation gives the outcome cancelled and keeps completed exchanges")
    func cancellation() async throws {
        let fixture = try FixtureFiles.trace("synthetic-fido2-getinfo-chained")
        let simulator = simulator(fixture, transport: try MockTransport(trace: fixture, realtime: true))
        let task = Task { await simulator.diagnostics { _ in } }
        try await Task.sleep(for: .milliseconds(1505))
        task.cancel()
        let result = await task.value
        #expect(result.trace.outcome == .cancelled)
        #expect(result.error == nil)
        #expect(result.trace.endReason == .cancelled)
        #expect(result.trace.exchanges.count < fixture.exchanges.count)
    }

    @Test(
        "Each CardError ends the trace with its own reason",
        arguments: [
            (CardError.userCancelled, SessionEndReason.userCancelled),
            (.sessionTimeout, .sessionTimeout),
            (.tagConnectionLost, .tagConnectionLost),
            (.nfcUnavailable, .nfcUnavailable),
            (.invalidAPDU, .invalidAPDU),
            (.notConnected, .notConnected),
            (.underlying(CocoaError(.fileReadUnknown)), .transportError),
        ]
    )
    func cardErrorReason(error: CardError, reason: SessionEndReason) async {
        let result = await FIDOSimulator(transport: FailingTransport(error: error), configuration: FIDOSimConfiguration())
            .diagnostics { _ in }
        #expect(result.trace.endReason == reason)
        #expect(result.trace.outcome?.status == (reason == .userCancelled ? .cancelled : .failure))
    }

    @Test("A transport that never connects still returns a trace")
    func openFails() async {
        let result = await FIDOSimulator(transport: FailingTransport(error: .sessionTimeout, failsOpen: true),
                                         configuration: FIDOSimConfiguration(cardLabel: "Lab card A"))
            .diagnostics { _ in }
        #expect(result.trace.exchanges.isEmpty)
        #expect(result.trace.endReason == .sessionTimeout)
        #expect(result.trace.card.label == "Lab card A")
        #expect(result.error?.domain == .transport)
    }
}
