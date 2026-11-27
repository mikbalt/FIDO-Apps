import FIDOKit
import Foundation
import Testing
@testable import FIDOSims

@MainActor
@Suite("Register and Authenticate view models")
struct CredentialViewModelTests {
    @Test("Register: random username format, and Run needs NFC, a label, a username and a PIN")
    func registerCanRun() {
        let name = RegisterViewModel.randomUsername()
        #expect(name.hasPrefix("nusa-") && name.count == 8)

        let model = RegisterViewModel(environment: TestSupport.environment())
        #expect(model.canRun)
        model.username = ""
        #expect(!model.canRun)
        model.useRandomUsername()
        #expect(model.canRun)
        model.pinSource = .stored  // nothing stored
        #expect(!model.canRun)
        model.pinSource = .custom
        #expect(!model.canRun)
        model.customPIN = "5678"
        #expect(model.canRun)
        #expect(!RegisterViewModel(environment: TestSupport.environment(nfc: false)).canRun)
    }

    @Test("Register against a fake card: the outcome, the stored registration and a saved run")
    func registerRuns() async throws {
        let credentials = CredentialStore()
        let history = TraceStore(directory: FileManager.default.temporaryDirectory.appending(path: "fidosims-t-\(UUID().uuidString)"))
        let card = FakeAuthenticator(pin: "1234")
        let model = RegisterViewModel(environment: TestSupport.environment(card: card, credentials: credentials, history: history))
        model.username = "nusa-042"
        model.run()
        await TestSupport.waitUntilIdle(model.runner)

        #expect(model.setupError == nil)
        #expect(model.runner.lastError == nil)
        let outcome = try #require(model.outcome)
        #expect(outcome.passed)
        #expect(credentials.all().map(\.username) == ["nusa-042"])
        #expect(model.runner.steps.last == .completed)
        #expect(model.runner.latestTrace?.scenario == .register)
        #expect(history.list().first?.id == model.runner.latestTrace?.id)
    }

    @Test("Register with a wrong PIN: failed run, no outcome, nothing stored")
    func registerWrongPIN() async {
        let credentials = CredentialStore()
        let model = RegisterViewModel(environment: TestSupport.environment(card: FakeAuthenticator(pin: "1234"), credentials: credentials))
        model.pinSource = .custom
        model.customPIN = "9999"
        model.run()
        await TestSupport.waitUntilIdle(model.runner)
        #expect(model.runner.lastError?.name == "CTAP2_ERR_PIN_INVALID")
        #expect(model.outcome == nil)
        #expect(credentials.all().isEmpty)
    }

    @Test("Authenticate: picks the newest registration, warns on an invalidated one, and cannot run without one")
    func authenticateSelection() throws {
        let credentials = CredentialStore()
        let empty = AuthenticateViewModel(environment: TestSupport.environment(credentials: credentials))
        #expect(empty.selectedCredential == nil)
        #expect(!empty.canRun)

        var item = StoredCredential(
            credentialId: Data([1]), rpId: "fidosims.example", userHandle: Data(count: 16), username: "nusa-001", cardLabel: "Card X",
            publicKeyCOSE: Data([0xA0]), signCount: 0, discoverable: false, attestationFormat: "none")
        try credentials.save(item)
        let model = AuthenticateViewModel(environment: TestSupport.environment(credentials: credentials))
        #expect(model.selectedCredential?.id == item.id)
        #expect(model.cardLabel == "Card X")
        #expect(model.selectionWarning == nil)
        #expect(model.canRun)

        item.invalidated = true
        try credentials.save(item)
        model.reload()
        #expect(model.selectionWarning != nil)
        #expect(model.canRun)  // still allowed: the request is sent anyway
    }

    @Test("Register then Authenticate against the same fake card; the counter and last used are saved")
    func registerThenAuthenticate() async throws {
        let credentials = CredentialStore()
        let card = FakeAuthenticator(pin: "1234")
        let environment = TestSupport.environment(card: card, credentials: credentials)
        let register = RegisterViewModel(environment: environment)
        register.run()
        await TestSupport.waitUntilIdle(register.runner)

        let authenticate = AuthenticateViewModel(environment: environment)
        authenticate.run()
        await TestSupport.waitUntilIdle(authenticate.runner)

        let outcome = try #require(authenticate.outcome)
        #expect(outcome.passed, "\(outcome.checks.filter { !$0.passed })")
        #expect(credentials.all().first?.signCount == 1)
        #expect(credentials.all().first?.lastUsedAt != nil)
        #expect(authenticate.credentials.first?.signCount == 1)
    }

    @Test("After a card reset the registration is invalidated and the card refuses it with 0x2E")
    func afterReset() async throws {
        let credentials = CredentialStore()
        let card = FakeAuthenticator(pin: "1234")
        let environment = TestSupport.environment(card: card, credentials: credentials)
        let register = RegisterViewModel(environment: environment)
        register.run()
        await TestSupport.waitUntilIdle(register.runner)

        let reset = ResetViewModel(environment: environment)
        reset.confirmation = reset.cardLabel
        reset.run()
        await TestSupport.waitUntilIdle(reset.runner)
        #expect(credentials.all().first?.invalidated == true)

        let setPIN = SetPINViewModel(environment: environment)
        setPIN.run()
        await TestSupport.waitUntilIdle(setPIN.runner)

        let authenticate = AuthenticateViewModel(environment: environment)
        #expect(authenticate.selectionWarning != nil)
        authenticate.run()
        await TestSupport.waitUntilIdle(authenticate.runner)
        #expect(authenticate.runner.lastError?.code == "0x2E")
        #expect(authenticate.outcome == nil)
    }
}
