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
