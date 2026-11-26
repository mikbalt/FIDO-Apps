import FIDOKit
import Foundation
import Testing
@testable import FIDOSims

@MainActor
@Suite("Change PIN and Set PIN view models")
struct PINViewModelTests {
    private let label = "Lab card A"

    // MARK: PIN source resolution

    @Test("PIN source resolution: default 1234, custom, stored")
    func resolve() throws {
        let store = InMemoryPINStore()
        let model = SetPINViewModel(environment: TestSupport.environment(store: store))
        #expect(model.resolve(.defaultPIN, custom: "") == "1234")
        #expect(model.resolve(.custom, custom: "") == nil)
        #expect(model.resolve(.custom, custom: "4321") == "4321")
        #expect(model.resolve(.stored, custom: "ignored") == nil)
        #expect(!model.hasStoredPIN)

        try store.savePIN("9876", for: label)
        #expect(model.resolve(.stored, custom: "ignored") == "9876")
        #expect(model.hasStoredPIN)
        model.cardLabel = "Other card"
        #expect(model.resolve(.stored, custom: "") == nil)
    }

    // MARK: canRun

    @Test("Set PIN canRun: needs NFC, a card label and a resolvable PIN")
    func setPINCanRun() throws {
        let store = InMemoryPINStore()
        let model = SetPINViewModel(environment: TestSupport.environment(store: store))
        #expect(model.canRun)

        model.source = .custom
        #expect(!model.canRun)
        model.customPIN = "4321"
        #expect(model.canRun)

        model.source = .stored
        #expect(!model.canRun)
        try store.savePIN("9876", for: label)
        #expect(model.canRun)

        model.cardLabel = ""
        #expect(!model.canRun)

        let noNFC = SetPINViewModel(environment: TestSupport.environment(nfc: false))
        #expect(!noNFC.canRun)
    }

    @Test("Change PIN canRun: also needs a new PIN")
    func changePINCanRun() {
        let model = ChangePINViewModel(environment: TestSupport.environment())
        #expect(!model.canRun)
        model.newPIN = "5678"
        #expect(model.canRun)

        model.currentSource = .custom
        #expect(!model.canRun)
        model.customCurrent = "1234"
        #expect(model.canRun)

        model.currentSource = .stored
        #expect(!model.canRun)

        model.currentSource = .defaultPIN
        model.cardLabel = ""
        #expect(!model.canRun)

        let noNFC = ChangePINViewModel(environment: TestSupport.environment(nfc: false))
        noNFC.newPIN = "5678"
        #expect(!noNFC.canRun)
    }

    // MARK: Store PIN

    @Test("Set PIN stores the PIN only after success, and only when asked")
    func setPINStore() async throws {
        let store = InMemoryPINStore()
        let card = FakeAuthenticator()
        let model = SetPINViewModel(environment: TestSupport.environment(card: card, store: store))
        model.source = .custom
        model.customPIN = "4321"
        model.storePIN = true
        model.run()
        // Not stored while the run is in progress.
        #expect(model.runner.isRunning)
        #expect(try store.loadPIN(for: label) == nil)
        await TestSupport.waitUntilIdle(model.runner)
        #expect(model.runner.latestOutcome == .success)
        #expect(try store.loadPIN(for: label) == "4321")
        #expect(model.setupError == nil)

        let unstored = InMemoryPINStore()
        let other = SetPINViewModel(environment: TestSupport.environment(card: FakeAuthenticator(), store: unstored))
        other.run()
        await TestSupport.waitUntilIdle(other.runner)
        #expect(other.runner.latestOutcome == .success)
        #expect(try unstored.loadPIN(for: label) == nil)
    }

    @Test("Set PIN does not store the PIN when the card refuses")
    func setPINFailure() async throws {
        let store = InMemoryPINStore()
        // A card that already has a PIN refuses Set PIN.
        let model = SetPINViewModel(environment: TestSupport.environment(card: FakeAuthenticator(pin: "1234"), store: store))
        model.storePIN = true
        model.run()
        await TestSupport.waitUntilIdle(model.runner)
        #expect(model.runner.latestOutcome?.status != .success)
        #expect(try store.loadPIN(for: label) == nil)
    }

    @Test("Change PIN stores the new PIN after success, not after a wrong current PIN")
    func changePINStore() async throws {
        let store = InMemoryPINStore()
        let card = FakeAuthenticator(pin: "1234")
        let model = ChangePINViewModel(environment: TestSupport.environment(card: card, store: store))
        model.newPIN = "5678"
        model.storePIN = true

        model.currentSource = .custom
        model.customCurrent = "0000"
        model.run()
        await TestSupport.waitUntilIdle(model.runner)
        #expect(model.runner.latestOutcome?.status == .failure)
        #expect(try store.loadPIN(for: label) == nil)

        model.currentSource = .defaultPIN
        model.run()
        await TestSupport.waitUntilIdle(model.runner)
        #expect(model.runner.latestOutcome == .success)
        #expect(try store.loadPIN(for: label) == "5678")
    }

    @Test("A transport that cannot be made becomes setupError and no run starts")
    func setupError() {
        let model = SetPINViewModel(environment: TestSupport.environment(card: nil))
        model.run()
        #expect(model.setupError != nil)
        #expect(!model.runner.isRunning)
        #expect(model.runner.history.isEmpty)
    }
}
