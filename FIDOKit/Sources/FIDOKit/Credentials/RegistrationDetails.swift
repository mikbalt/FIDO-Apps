import Foundation

/// What the Registrations detail view shows besides the `StoredCredential` fields. The contract struct has
/// no place for them, so the store keeps them next to it.
public struct RegistrationDetails: Codable, Sendable, Equatable {
    public let aaguid: Data
    /// The authenticatorData flags byte of the registration, e.g. `0x45`.
    public let flags: UInt8

    public init(aaguid: Data, flags: UInt8) {
        self.aaguid = aaguid
        self.flags = flags
    }
}
