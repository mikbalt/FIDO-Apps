import CardCore
import Foundation
import Testing

@Suite("TraceRecorder")
struct TraceRecorderTests {
    private func makeRecorder(start: ContinuousClock.Instant) -> TraceRecorder {
        TraceRecorder(
            metadata: TraceMetadata(transport: .mock, cardLabel: "Card", options: TraceOptions()),
            connection: CardConnection(
                sessionStartedAt: start, cardDetectedAt: start + .milliseconds(10), initialSelectedAID: nil
            )
        )
    }

    @Test("Times are nanoseconds since sessionStarted, and indices are 1-based")
    func offsets() async throws {
        let start = ContinuousClock.now
        let recorder = makeRecorder(start: start)
        let command = await recorder.nextCommandIndex()
        await recorder.record(
            RawExchange(
                command: Data([0x00]), response: ResponseAPDU(sw: .success),
                startedAt: start + .microseconds(10_100), endedAt: start + .microseconds(12_350)
            ),
            commandIndex: command, label: "X", sensitive: true
        )
        let trace = await recorder.trace
        #expect(command == 1)
        #expect(trace.cardDetectedTime == 10_000_000)
        let exchange = try #require(trace.exchanges.first)
        #expect(exchange.index == 1)
        #expect(exchange.tStart == 10_100_000)
        #expect(exchange.tEnd == 12_350_000)
        #expect(exchange.sensitive)
    }

    @Test("sessionEnded is recorded once and never before the last exchange")
    func endClamped() async {
        let start = ContinuousClock.now
        let recorder = makeRecorder(start: start)
        await recorder.record(
            RawExchange(
                command: Data([0x00]), response: ResponseAPDU(sw: .success),
                startedAt: start + .seconds(1), endedAt: start + .seconds(2)
            ),
            commandIndex: 1, label: "X", sensitive: false
        )
        await recorder.end(reason: .completed, at: start + .milliseconds(500))
        await recorder.end(reason: .error)
        let trace = await recorder.trace
        #expect(trace.events.last == .sessionEnded(t: 2_000_000_000, reason: .completed))
        #expect(trace.endReason == .completed)
    }

    @Test("Concurrent records are all kept, with unique indices")
    func concurrentRecords() async {
        let start = ContinuousClock.now
        let recorder = makeRecorder(start: start)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await recorder.record(
                        RawExchange(command: Data(), response: ResponseAPDU(sw: .success), startedAt: start, endedAt: start),
                        commandIndex: 1, label: "X", sensitive: false
                    )
                }
            }
        }
        let indices = await recorder.trace.exchanges.map(\.index)
        #expect(Set(indices) == Set(1...100))
    }
}
