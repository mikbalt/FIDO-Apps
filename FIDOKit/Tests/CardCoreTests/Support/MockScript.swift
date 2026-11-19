import CardCore
import Foundation

/// Builds an in-memory trace to drive `MockTransport` in channel tests.
enum MockScript {
    struct Step {
        var tx: String
        var rx: String = ""
        var sw: String
    }

    /// Each step takes 1 ms, with 0.1 ms between steps; the card is detected at 100 ms.
    static func trace(_ steps: [Step], options: TraceOptions = TraceOptions()) throws -> Trace {
        var events: [TraceEvent] = [.sessionStarted(t: 0), .cardDetected(t: 100_000_000)]
        var t: Int64 = 100_000_000
        for (offset, step) in steps.enumerated() {
            let start = t + 100_000
            let end = start + 1_000_000
            events.append(.exchange(ExchangeEvent(
                index: offset + 1, commandIndex: 1, label: "SCRIPT",
                tx: try Hex.parse(step.tx), rx: try Hex.parse(step.rx),
                sw: StatusWord(rawValue: UInt16(step.sw, radix: 16) ?? 0),
                tStart: start, tEnd: end, sensitive: false
            )))
            t = end
        }
        return Trace(
            id: UUID(), createdAt: Date(timeIntervalSince1970: 0),
            app: AppInfo(name: "Tests", version: "0", build: "0"), transport: .mock,
            device: DeviceInfo(model: "Test", os: "test"),
            card: CardInfo(label: "Script", initialSelectedAID: nil),
            options: options, events: events
        )
    }

    static func transport(_ steps: [Step]) throws -> MockTransport {
        try MockTransport(trace: trace(steps))
    }
}
