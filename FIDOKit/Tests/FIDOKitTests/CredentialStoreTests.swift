import Foundation
import Testing
@testable import FIDOKit

@Suite("CredentialStore")
struct CredentialStoreTests {
    private func credential(card: String = "Card A", id: UInt8 = 1, createdAt: Date = Date(timeIntervalSince1970: 1_000)) -> StoredCredential {
        StoredCredential(
            credentialId: Data([id]), rpId: "fidosims.example", userHandle: Data(repeating: id, count: 16), username: "nusa-0\(id)",
            cardLabel: card, publicKeyCOSE: Data([0xA1, id]), signCount: 0, discoverable: false, attestationFormat: "none",
            createdAt: createdAt)
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "fidosims-\(UUID().uuidString)").appending(path: "credentials.json")
    }

    @Test("Saves, reloads from the file, and keeps the details next to the credential")
    func roundTrip() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CredentialStore(fileURL: file)
        let saved = credential()
        try store.save(saved, details: RegistrationDetails(aaguid: Data(repeating: 0xA5, count: 16), flags: 0x45))

        let reloaded = try CredentialStore(fileURL: file)
        #expect(reloaded.all() == [saved])
        #expect(reloaded.credential(id: saved.id) == saved)
        #expect(reloaded.details(for: saved.id)?.flags == 0x45)
        #expect(reloaded.contains(credentialId: Data([1])))
        #expect(!reloaded.contains(credentialId: Data([2])))
    }

    @Test("Saving the same id updates it and keeps the details")
    func update() throws {
        let store = CredentialStore()
        var item = credential()
        try store.save(item, details: RegistrationDetails(aaguid: Data(count: 16), flags: 0x45))
        item.signCount = 9
        item.lastUsedAt = Date(timeIntervalSince1970: 2_000)
        try store.save(item)
        #expect(store.all().count == 1)
        #expect(store.all().first?.signCount == 9)
        #expect(store.details(for: item.id)?.flags == 0x45)
    }

    @Test("The reset hook invalidates only that card's credentials")
    func invalidate() throws {
        let store = CredentialStore()
        try store.save(credential(card: "Card A", id: 1))
        try store.save(credential(card: "Card A", id: 2))
        try store.save(credential(card: "Card B", id: 3))
        #expect(try store.invalidateCredentials(forCard: "Card A") == 2)
        #expect(try store.invalidateCredentials(forCard: "Card A") == 0)
        #expect(Set(store.all().filter(\.invalidated).map(\.cardLabel)) == ["Card A"])
    }

    @Test("Delete removes the credential, and it stays removed after a reload")
    func delete() throws {
        let file = temporaryFile()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = try CredentialStore(fileURL: file)
        let item = credential()
        try store.save(item)
        try store.delete(id: item.id)
        #expect(try CredentialStore(fileURL: file).all().isEmpty)
    }

    @Test("Newest first")
    func order() throws {
        let store = CredentialStore()
        try store.save(credential(id: 1, createdAt: Date(timeIntervalSince1970: 1)))
        try store.save(credential(id: 2, createdAt: Date(timeIntervalSince1970: 3)))
        try store.save(credential(id: 3, createdAt: Date(timeIntervalSince1970: 2)))
        #expect(store.all().map(\.credentialId) == [Data([2]), Data([3]), Data([1])])
    }

    @Test("A corrupt file is an error and is not overwritten")
    func corrupt() throws {
        let file = temporaryFile()
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        try Data("not json".utf8).write(to: file)
        #expect(throws: (any Error).self) { try CredentialStore(fileURL: file) }
        #expect(try Data(contentsOf: file) == Data("not json".utf8))
    }
}
