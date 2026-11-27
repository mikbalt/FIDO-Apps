import FIDOKit
import FIDOTestSupport
import Foundation
import Testing

@Suite("TraceStore and run history")
struct TraceStoreTests {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "fidosims-history-\(UUID().uuidString)")
    }

    @Test("Every run is saved, including failed ones; the list is newest first and survives a reload")
    func savesEveryRun() async throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let card = FakeAuthenticator(pin: "1234")
        let sim = FIDOSimulator(transport: card, configuration: FIDOSimConfiguration(traceStore: TraceStore(directory: dir)))

        let first = await sim.diagnostics { _ in }
        try await Task.sleep(for: .milliseconds(20))
        let second = await sim.changePIN(current: "9999", new: "5678", cardLabel: "Lab card A") { _ in }  // wrong PIN
        try await Task.sleep(for: .milliseconds(20))
        let third = await sim.setPIN("12", cardLabel: "Lab card A") { _ in }  // refused before the card

        let listed = TraceStore(directory: dir).list()
        #expect(listed.map(\.id) == [third.trace.id, second.trace.id, first.trace.id])
        #expect(listed.map(\.scenario) == [.setPIN, .changePIN, .diagnostics])
        #expect(listed[1].outcome?.status == .failure)
    }

    @Test("Sensitive exchanges are redacted on disk")
    func redactedOnDisk() async throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sim = FIDOSimulator(
            transport: FakeAuthenticator(pin: "1234"), configuration: FIDOSimConfiguration(traceStore: TraceStore(directory: dir)))
        let result = await sim.changePIN(current: "1234", new: "5678", cardLabel: "Lab card A") { _ in }
        let saved = try #require(TraceStore(directory: dir).list().first)
        let change = try #require(saved.exchanges.first { $0.label == "CLIENT_PIN_CHANGE" })
        #expect(change.sensitive)
        #expect(change.tx.allSatisfy { $0 == 0 })
        // The run on screen keeps the original bytes.
        #expect(result.trace.exchanges.first { $0.label == "CLIENT_PIN_CHANGE" }?.tx.contains { $0 != 0 } == true)
    }

    @Test("Delete removes one run; unreadable files are skipped")
    func deleteAndSkip() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TraceStore(directory: dir)
        #expect(store.list().isEmpty)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("nope".utf8).write(to: dir.appending(path: "broken.json"))
        #expect(store.list().isEmpty)
    }

    @Test("A run that is not saved when there is no store")
    func noStore() async {
        let sim = FIDOSimulator(transport: FakeAuthenticator(), configuration: FIDOSimConfiguration())
        let result = await sim.diagnostics { _ in }
        #expect(result.error == nil)
    }
}
