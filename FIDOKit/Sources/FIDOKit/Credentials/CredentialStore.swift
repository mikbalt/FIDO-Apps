import Foundation
import os

/// The local RP's credentials, kept as one Codable JSON file written atomically.
///
/// Safe to call from any thread.
public final class CredentialStore: Sendable {
    private struct Record: Codable, Sendable {
        var credential: StoredCredential
        var details: RegistrationDetails?
    }

    private let fileURL: URL?
    private let records: OSAllocatedUnfairLock<[Record]>

    /// A store that lives in memory only (tests, mock runs).
    public init() {
        fileURL = nil
        records = OSAllocatedUnfairLock(initialState: [])
    }

    /// - Throws: if the file exists but cannot be read or decoded. It is never overwritten in that case.
    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        var loaded: [Record] = []
        if FileManager.default.fileExists(atPath: fileURL.path) {
            loaded = try Self.decoder.decode([Record].self, from: Data(contentsOf: fileURL))
        }
        records = OSAllocatedUnfairLock(initialState: loaded)
    }

    /// `Application Support/FIDOSims/credentials.json`.
    public static func defaultFileURL() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "FIDOSims", directoryHint: .isDirectory)
            .appending(path: "credentials.json")
    }

    // MARK: Reading

    /// Newest first.
    public func all() -> [StoredCredential] {
        records.withLock { $0.map(\.credential) }.sorted { $0.createdAt > $1.createdAt }
    }

    public func credential(id: UUID) -> StoredCredential? {
        records.withLock { $0.first { $0.credential.id == id }?.credential }
    }

    public func details(for id: UUID) -> RegistrationDetails? {
        records.withLock { $0.first { $0.credential.id == id }?.details }
    }

    public func contains(credentialId: Data) -> Bool {
        records.withLock { $0.contains { $0.credential.credentialId == credentialId } }
    }

    // MARK: Writing

    /// Adds the credential, or replaces the one with the same `id`. Existing details are kept when `details` is nil.
    public func save(_ credential: StoredCredential, details: RegistrationDetails? = nil) throws {
        try update { records in
            if let index = records.firstIndex(where: { $0.credential.id == credential.id }) {
                records[index] = Record(credential: credential, details: details ?? records[index].details)
            } else {
                records.append(Record(credential: credential, details: details))
            }
        }
    }

    public func delete(id: UUID) throws {
        try update { $0.removeAll { $0.credential.id == id } }
    }

    /// The reset hook: marks every credential of the card `invalidated`. Returns how many changed.
    @discardableResult
    public func invalidateCredentials(forCard cardLabel: String) throws -> Int {
        var changed = 0
        try update { records in
            for index in records.indices where records[index].credential.cardLabel == cardLabel && !records[index].credential.invalidated {
                records[index].credential.invalidated = true
                changed += 1
            }
        }
        return changed
    }

    // MARK: Private

    /// Applies `change` to a copy, writes it, and only then keeps it: a failed write leaves memory unchanged.
    private func update(_ change: (inout [Record]) -> Void) throws {
        try records.withLockUnchecked { current in
            var copy = current
            change(&copy)
            if let fileURL {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Self.encoder.encode(copy).write(to: fileURL, options: .atomic)
            }
            current = copy
        }
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
