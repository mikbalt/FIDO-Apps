import CardCore
import CTAP
import Foundation

/// Builds a MockTransport-backed `CTAPClient` from scripted exchanges.
enum CTAPScript {
    struct Step {
        var tx: String
        var rx: String = ""
        var sw: String = "9000"
    }

    /// Each step takes 1 ms; the card is detected at 100 ms.
    static func trace(_ steps: [Step]) throws -> Trace {
        var events: [TraceEvent] = [.sessionStarted(t: 0), .cardDetected(t: 100_000_000)]
        for (offset, step) in steps.enumerated() {
            let start = Int64(100_000_000 + offset * 2_000_000)
            events.append(.exchange(ExchangeEvent(
                index: offset + 1, commandIndex: offset + 1, label: "SCRIPT",
                tx: try Hex.parse(step.tx), rx: try Hex.parse(step.rx),
                sw: StatusWord(rawValue: UInt16(step.sw, radix: 16) ?? 0),
                tStart: start, tEnd: start + 1_000_000, sensitive: false
            )))
        }
        return Trace(
            id: UUID(), createdAt: Date(timeIntervalSince1970: 0),
            app: AppInfo(name: "Tests", version: "0", build: "0"), transport: .mock,
            device: DeviceInfo(model: "Test", os: "test"),
            card: CardInfo(label: "Script", initialSelectedAID: nil),
            options: TraceOptions(), events: events
        )
    }

    static func client(_ steps: [Step]) async throws -> (CTAPClient, MockTransport) {
        let transport = try MockTransport(trace: trace(steps))
        let connection = try await transport.open(prompt: "")
        let recorder = TraceRecorder(
            metadata: TraceMetadata(transport: .mock, cardLabel: "Script", options: TraceOptions()),
            connection: connection
        )
        let channel = ISO7816Channel(transport: transport, recorder: recorder)
        return (CTAPClient(channel: channel), transport)
    }
}
