import Foundation

/// The result of a registration that reached the end of the card session.
///
/// The card answering is not the same as the RP accepting: look at `passed` and `checks`.
public struct RegistrationOutcome: Sendable, Equatable {
    /// The `toJSON()` of the new credential. `nil` only if the attestation statement could not be encoded.
    public let result: RegistrationResultJSON?
    public let checks: [RPCheck]
    /// The saved registration. `nil` when a check failed.
    public let credential: StoredCredential?
    /// Why the credential could not be saved, when the checks passed but the store refused.
    public let saveError: String?

    public var passed: Bool { checks.allSatisfy(\.passed) && credential != nil && saveError == nil }
}
