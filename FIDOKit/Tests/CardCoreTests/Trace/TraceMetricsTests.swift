import CardCore
import Testing

@Suite("Trace metrics")
struct TraceMetricsTests {
    @Test("Known numbers for the chained GetInfo fixture")
    func chainedFixture() throws {
        let metrics = TraceMetrics(trace: try Fixtures.trace("synthetic-fido2-getinfo-chained"))
        #expect(metrics.cardWait == 1_500_000_000)
        #expect(metrics.apduTotal == 91_000_000)
        #expect(metrics.sessionTotal == 1_593_100_000)
        #expect(metrics.hostOverhead == 2_100_000)
        #expect(metrics.exchangeCount == 5)
        #expect(metrics.commands == [
            CommandMetrics(commandIndex: 1, label: "SELECT_FIDO", rtt: 12_400_000, exchangeCount: 1),
            CommandMetrics(commandIndex: 2, label: "GET_INFO", rtt: 78_600_000, exchangeCount: 4),
        ])
    }

    @Test("v2 timeline: known segments that add up exactly to scenarioTotal")
    func v2Timeline() throws {
        let metrics = TraceMetrics(trace: try Fixtures.trace("synthetic-v2-timeline"))
        #expect(metrics.preSession == 20_000_000)
        #expect(metrics.cardWait == 1_500_000_000)
        #expect(metrics.cardPhase == 83_200_000)
        #expect(metrics.apduTotal == 82_000_000)
        #expect(metrics.inSessionHost == 1_200_000)
        #expect(metrics.postSession == 96_800_000)
        #expect(metrics.scenarioTotal == 1_700_000_000)
        #expect(metrics.sessionTotal == 1_583_200_000)

        let segments = [metrics.preSession, metrics.cardWait, metrics.cardPhase, metrics.postSession].compactMap { $0 }
        #expect(segments.count == 4)
        #expect(segments.reduce(0, +) == metrics.scenarioTotal)
        #expect(metrics.cardWait.map { $0 + (metrics.cardPhase ?? 0) } == metrics.sessionTotal)
        #expect(metrics.apduTotal + (metrics.inSessionHost ?? 0) == metrics.cardPhase)

        #expect(metrics.commandTotals == [
            LabelTotal(label: "SELECT_FIDO", count: 1, total: 12_000_000),
            LabelTotal(label: "GET_INFO", count: 1, total: 70_200_000),
        ])
        #expect(metrics.hostStepTotals == [LabelTotal(label: "CBOR_DECODE", count: 1, total: 200_000)])
    }

    @Test("v1 fixtures have no v2 segments, and the v1 metrics are unchanged")
    func v1HasNoSegments() throws {
        let metrics = TraceMetrics(trace: try Fixtures.trace("synthetic-fido2-getinfo-chained"))
        #expect(metrics.preSession == nil)
        #expect(metrics.postSession == nil)
        #expect(metrics.scenarioTotal == nil)
        #expect(metrics.cardPhase == 93_100_000)
        #expect(metrics.inSessionHost == metrics.hostOverhead)
        #expect(metrics.commandTotals.isEmpty)
    }

    @Test("Per-label totals sum repeated labels in order of first appearance")
    func labelTotals() throws {
        var trace = try Fixtures.trace("synthetic-v2-timeline")
        trace.events.append(.hostStep(HostStepEvent(label: "CBOR_ENCODE", tStart: 0, tEnd: 10)))
        trace.events.append(.hostStep(HostStepEvent(label: "CBOR_DECODE", tStart: 0, tEnd: 5)))
        #expect(TraceMetrics(trace: trace).hostStepTotals == [
            LabelTotal(label: "CBOR_DECODE", count: 2, total: 200_005),
            LabelTotal(label: "CBOR_ENCODE", count: 1, total: 10),
        ])
    }

    @Test("A trace without exchanges has no session total")
    func noExchanges() throws {
        var trace = try Fixtures.trace("synthetic-select-fail")
        trace.events.removeAll { if case .exchange = $0 { true } else { false } }
        let metrics = TraceMetrics(trace: trace)
        #expect(metrics.cardWait == 900_000_000)
        #expect(metrics.sessionTotal == nil)
        #expect(metrics.hostOverhead == nil)
        #expect(metrics.apduTotal == 0)
    }

    @Test("Milliseconds with 3 decimals", arguments: [
        (12_400_000, "12.400 ms"),
        (1_842_700_000, "1842.700 ms"),
        (0, "0.000 ms"),
        (999, "0.001 ms"),
        (499, "0.000 ms"),
        (-20_200_000, "-20.200 ms"),
    ] as [(Int64, String)])
    func millisecondFormat(nanoseconds: Int64, expected: String) {
        #expect(TimingFormat.milliseconds(nanoseconds) == expected)
    }
}
