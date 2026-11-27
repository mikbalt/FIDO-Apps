import FIDOKit
import Foundation
import Observation

/// The registrations in the credential store, newest first.
@MainActor
@Observable
final class RegistrationsViewModel {
    private(set) var credentials: [StoredCredential] = []
    private(set) var error: String?

    private let store: CredentialStore

    init(store: CredentialStore) {
        self.store = store
        reload()
    }

    func reload() {
        credentials = store.all()
    }

    func delete(_ credential: StoredCredential) {
        do {
            try store.delete(id: credential.id)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        reload()
    }

    func details(for credential: StoredCredential) -> RegistrationDetails? {
        store.details(for: credential.id)
    }
}
