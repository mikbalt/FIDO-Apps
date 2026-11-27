import FIDOKit
import FIDOTestSupport
import Foundation
import Testing

@Suite("FIDOSimulator register and authenticate against a fake card")
struct CredentialScenarioTests {
    private func simulator(_ card: FakeAuthenticator, store: CredentialStore) -> FIDOSimulator {
        FIDOSimulator(transport: card, configuration: FIDOSimConfiguration(credentialStore: store))
    }

    private func labels(_ trace: Trace) -> [String] {
        var seen: [String] = []
        for label in trace.exchanges.map(\.label) where seen.last != label {
            seen.append(label)
        }
        return seen
    }

    private func register(_ sim: FIDOSimulator, pin: String = "1234", rk: Bool = false) async -> ScenarioResult<RegistrationOutcome> {
        await sim.register(RegistrationRequest(username: "nusa-042", pin: pin, cardLabel: "Lab card A", residentKey: rk)) { _ in }
    }

    @Test("Register: the brief's command sequence and progress steps, all checks pass, the credential is stored")
    func register() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let store = CredentialStore()
        let log = ProgressLog()
        let result = await simulator(card, store: store).register(
            RegistrationRequest(username: "nusa-042", pin: "1234", cardLabel: "Lab card A"), progress: log.callback())

        #expect(result.error == nil)
        #expect(labels(result.trace) == ["SELECT_FIDO", "GET_INFO", "CLIENT_PIN_KEY_AGREEMENT", "CLIENT_PIN_TOKEN", "MAKE_CREDENTIAL"])
        #expect(log.events == [
            .waitingForCard, .cardDetected, .executing("SELECT_FIDO"), .executing("GET_INFO"),
            .executing("CLIENT_PIN_KEY_AGREEMENT"), .executing("CLIENT_PIN_TOKEN"), .pinVerified,
            .executing("Creating credential"), .executing("Verify and save"), .completed,
        ])
        #expect(result.trace.scenario == .register)
        #expect(result.trace.outcome == .success)
        #expect(result.trace.endReason == .completed)
        #expect(result.trace.exchanges.first { $0.label == "CLIENT_PIN_TOKEN" }?.sensitive == true)

        let outcome = try #require(result.value)
        #expect(outcome.passed, "\(outcome.checks.filter { !$0.passed })")
        let credential = try #require(outcome.credential)
        #expect(store.all() == [credential])
        #expect(credential.username == "nusa-042")
        #expect(credential.cardLabel == "Lab card A")
        #expect(credential.rpId == "fidosims.example")
        #expect(credential.attestationFormat == "none")
        #expect(store.details(for: credential.id)?.flags == 0x45)
        #expect(outcome.result?.response.transports == ["nfc"])
        #expect(await card.tokenGrant?.permissions == 0x01)
    }

    @Test("A wrong PIN ends the session completed with a failed outcome, no value and nothing stored")
    func wrongPIN() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let store = CredentialStore()
        let result = await register(simulator(card, store: store), pin: "9999")
        #expect(result.value == nil)
        #expect(result.error?.name == "CTAP2_ERR_PIN_INVALID")
        #expect(result.trace.endReason == .completed)
        #expect(result.trace.outcome?.status == .failure)
        #expect(store.all().isEmpty)
        #expect(await card.commandsReceived.contains(0x01) == false)
    }

    @Test("A PIN that is too short is refused before anything is sent")
    func shortPIN() async {
        let card = FakeAuthenticator(pin: "1234")
        let result = await register(simulator(card, store: CredentialStore()), pin: "12")
        #expect(result.error?.name == "PIN_TOO_SHORT")
        #expect(await card.requests.isEmpty)
    }

    @Test("Authenticate: sequence, flags, signCount and lastUsedAt are saved")
    func authenticate() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let store = CredentialStore()
        let sim = simulator(card, store: store)
        let registered = try #require(await register(sim).value?.credential)

        let log = ProgressLog()
        let result = await sim.authenticate(
            AuthenticationRequest(credential: registered, pin: "1234", cardLabel: "Lab card A"), progress: log.callback())
        #expect(result.error == nil)
        #expect(labels(result.trace) == ["SELECT_FIDO", "GET_INFO", "CLIENT_PIN_KEY_AGREEMENT", "CLIENT_PIN_TOKEN", "GET_ASSERTION"])
        #expect(log.events.suffix(4) == [.pinVerified, .executing("Authenticating"), .executing("Verify and save"), .completed])
        #expect(result.trace.scenario == .authenticate)
        let outcome = try #require(result.value)
        #expect(outcome.passed, "\(outcome.checks.filter { !$0.passed })")
        #expect(outcome.credential.signCount == 1)
        #expect(outcome.credential.lastUsedAt != nil)
        #expect(store.credential(id: registered.id)?.signCount == 1)
        #expect(await card.tokenGrant?.permissions == 0x02)
    }

    @Test("After a card reset the card answers NO_CREDENTIALS and the stored signCount is untouched")
    func authenticateAfterReset() async throws {
        let card = FakeAuthenticator(pin: "1234")
        let store = CredentialStore()
        let sim = FIDOSimulator(transport: card, configuration: FIDOSimConfiguration(
            onCardReset: { label in _ = try? store.invalidateCredentials(forCard: label) }, credentialStore: store))
        let registered = try #require(await register(sim).value?.credential)

        let reset = await sim.reset(confirmedCardLabel: "Lab card A") { _ in }
        #expect(reset.error == nil)
        #expect(store.all().allSatisfy { $0.invalidated })

        _ = await sim.setPIN("1234", cardLabel: "Lab card A") { _ in }
        let invalidated = try #require(store.credential(id: registered.id))
        // Sent anyway, as the brief says; the card refuses.
        let result = await sim.authenticate(AuthenticationRequest(credential: invalidated, pin: "1234", cardLabel: "Lab card A")) { _ in }
        #expect(result.error?.code == "0x2E")
        #expect(result.value == nil)
        #expect(store.credential(id: registered.id)?.signCount == 0)
    }
}
