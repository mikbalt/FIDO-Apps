import FIDOKit
import FIDOTestSupport
import Foundation
import Testing

@Suite("FIDOSimulator PIN and reset scenarios against a fake card")
struct PINScenarioTests {
    private func simulator(
        _ card: FakeAuthenticator, store: InMemoryPINStore = InMemoryPINStore(),
        onReset: @escaping @Sendable (String) -> Void = { _ in }
    ) -> FIDOSimulator {
        FIDOSimulator(transport: card, configuration: FIDOSimConfiguration(pinStore: store, onCardReset: onReset))
    }

    private func labels(_ result: ScenarioResult<Void>) -> [String] {
        var seen: [String] = []
        for label in result.trace.exchanges.map(\.label) where seen.last != label {
            seen.append(label)
        }
        return seen
    }

    @Test("Change PIN: SELECT → GET_INFO → RETRIES → KEY_AGREEMENT → CHANGE; the old PIN no longer works")
    func changePIN() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let log = ProgressLog()
        let result = await simulator(card).changePIN(current: "1234", new: "5678", cardLabel: "Lab card A", progress: log.callback())
        #expect(result.error == nil)
        #expect(labels(result) == ["SELECT_FIDO", "GET_INFO", "CLIENT_PIN_RETRIES", "CLIENT_PIN_KEY_AGREEMENT", "CLIENT_PIN_CHANGE"])
        #expect(await card.pin == Data("5678".utf8))
        #expect(result.trace.scenario == .changePIN)
        #expect(result.trace.outcome == .success)
        #expect(log.events.suffix(2) == [.pinVerified, .completed])
        #expect(result.trace.exchanges.first { $0.label == "CLIENT_PIN_CHANGE" }?.sensitive == true)

        let again = await simulator(card).changePIN(current: "1234", new: "0000", cardLabel: "Lab card A") { _ in }
        #expect(again.error?.code == "0x31")
    }

    @Test("A wrong current PIN gives 0x31 with the remaining retries; retries go down by one")
    func wrongPIN() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let result = await simulator(card).changePIN(current: "9999", new: "5678", cardLabel: "Lab card A") { _ in }
        #expect(result.error?.domain == .ctap)
        #expect(result.error?.name == "CTAP2_ERR_PIN_INVALID")
        #expect(result.error?.message.hasSuffix("7 retries left.") == true)
        #expect(await card.retries == 7)
        #expect(result.trace.endReason == .completed)
        #expect(result.trace.outcome?.status == .failure)
        #expect(result.trace.exchanges.last { $0.label == "CLIENT_PIN_CHANGE" }?.ctapStatus == 0x31)
    }

    @Test("Set PIN on a blank card")
    func setPIN() async throws {
        let card = FakeAuthenticator()
        let result = await simulator(card).setPIN("1234", cardLabel: "Lab card A") { _ in }
        #expect(result.error == nil)
        #expect(labels(result) == ["SELECT_FIDO", "GET_INFO", "CLIENT_PIN_KEY_AGREEMENT", "CLIENT_PIN_SET"])
        #expect(await card.pin == Data("1234".utf8))
    }

    @Test("Set PIN fails early, with no ClientPIN command, if a PIN is already set")
    func setPINAlreadySet() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let result = await simulator(card).setPIN("5678", cardLabel: "Lab card A") { _ in }
        #expect(result.error?.name == "PIN_ALREADY_SET")
        #expect(labels(result) == ["SELECT_FIDO", "GET_INFO"])
        #expect(await card.commandsReceived == [0x04])
    }

    @Test("An invalid PIN is refused before anything is sent to the card")
    func invalidPINNotSent() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let short = await simulator(card).changePIN(current: "1234", new: "12", cardLabel: "Lab card A") { _ in }
        #expect(short.error?.name == "PIN_TOO_SHORT")
        #expect(short.trace.exchanges.isEmpty)
        #expect(await card.commandsReceived.isEmpty)
    }

    @Test("The card's minPINLength applies to the new PIN")
    func cardMinimum() async throws {
        let card = FakeAuthenticator()
        await card.configure(minPINLength: 6)
        let result = await simulator(card).setPIN("1234", cardLabel: "Lab card A") { _ in }
        #expect(result.error?.name == "PIN_TOO_SHORT")
        #expect(result.error?.message.contains("6") == true)
        #expect(await card.commandsReceived == [0x04])
    }

    @Test("A card without PIN protocol 2 stops with a clear error")
    func protocolOneOnly() async throws {
        let card = FakeAuthenticator(pin: "1234")
        await card.configure(pinProtocols: [1])
        let result = await simulator(card).changePIN(current: "1234", new: "5678", cardLabel: "Lab card A") { _ in }
        #expect(result.error?.name == "PIN_PROTOCOL_2_UNSUPPORTED")
        #expect(await card.commandsReceived == [0x04])
    }

    @Test("Reset: SELECT → RESET with no GetInfo; deletes the stored PIN and calls onCardReset")
    func reset() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let store = InMemoryPINStore()
        try store.savePIN("1234", for: "Lab card A")
        try store.savePIN("4321", for: "Other card")
        let resetLog = ResetLog()
        let result = await simulator(card, store: store, onReset: resetLog.record).reset(confirmedCardLabel: "Lab card A") { _ in }
        #expect(result.error == nil)
        #expect(labels(result) == ["SELECT_FIDO", "RESET"])
        #expect(await card.pin == nil)
        #expect(try store.loadPIN(for: "Lab card A") == nil)
        #expect(try store.loadPIN(for: "Other card") == "4321")
        #expect(resetLog.labels == ["Lab card A"])

        // GetInfo then shows no PIN, and Set PIN works.
        let setPIN = await simulator(card).setPIN("2468", cardLabel: "Lab card A") { _ in }
        #expect(setPIN.error == nil)
    }

    @Test("Reset refused with 0x30 explains the 10 s window and keeps the stored PIN")
    func resetNotAllowed() async throws {
        let card = FakeAuthenticator(pin: "1234")
        await card.configure(resetAllowed: false)
        let store = InMemoryPINStore()
        try store.savePIN("1234", for: "Lab card A")
        let resetLog = ResetLog()
        let result = await simulator(card, store: store, onReset: resetLog.record).reset(confirmedCardLabel: "Lab card A") { _ in }
        #expect(result.error?.name == "CTAP2_ERR_NOT_ALLOWED")
        #expect(result.error?.message.contains("Reset must happen within 10 s of tapping, or this card does not allow reset over NFC") == true)
        #expect(try store.loadPIN(for: "Lab card A") == "1234")
        #expect(resetLog.labels.isEmpty)
    }

    @Test("PINs never appear in the trace or its exports")
    func noSecretsInTrace() async throws {
        let card = FakeAuthenticator(pin: "8642")
        let result = await simulator(card).changePIN(current: "8642", new: "9753", cardLabel: "Lab card A") { _ in }
        let json = String(decoding: try result.trace.jsonData(), as: UTF8.self)
        let text = TraceTextExporter.text(for: result.trace)
        for secret in ["8642", "9753", Hex.compact(Data("8642".utf8)), Hex.compact(Data("9753".utf8))] {
            #expect(!json.contains(secret))
            #expect(!text.contains(secret))
        }
        #expect(text.contains("<redacted"))
    }
}
