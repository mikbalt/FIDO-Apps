import FIDOKit
import Foundation
import Testing
@testable import FIDOSims

@MainActor
@Suite("RegistrationsViewModel and the reset hook")
struct RegistrationsViewModelTests {
    private func credential(card: String, id: UInt8) -> StoredCredential {
        StoredCredential(
            credentialId: Data([id]), rpId: "fidosims.example", userHandle: Data(count: 16), username: "nusa-0\(id)", cardLabel: card,
            publicKeyCOSE: Data([0xA0]), signCount: 0, discoverable: false, attestationFormat: "none")
    }

    @Test("Lists the store, newest first, and delete removes the row and the stored credential")
    func listAndDelete() throws {
        let store = CredentialStore()
        let first = credential(card: "A", id: 1)
        try store.save(first)
        let model = RegistrationsViewModel(store: store)
        #expect(model.credentials == [first])

        model.delete(first)
        #expect(model.credentials.isEmpty)
        #expect(store.all().isEmpty)
    }

    @Test("reload picks up registrations made elsewhere")
    func reload() throws {
        let store = CredentialStore()
        let model = RegistrationsViewModel(store: store)
        try store.save(credential(card: "A", id: 1))
        #expect(model.credentials.isEmpty)
        model.reload()
        #expect(model.credentials.count == 1)
    }

    @Test("The environment's onCardReset marks only that card's registrations invalidated")
    func resetHook() throws {
        let store = CredentialStore()
        try store.save(credential(card: "A", id: 1))
        try store.save(credential(card: "B", id: 2))
        let environment = TestSupport.environment(credentials: store)
        environment.onCardReset("A")
        let model = RegistrationsViewModel(store: store)
        #expect(Dictionary(uniqueKeysWithValues: model.credentials.map { ($0.cardLabel, $0.invalidated) }) == ["A": true, "B": false])
    }
}
