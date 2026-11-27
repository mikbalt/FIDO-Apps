import Foundation

/// The result of an authentication that reached the end of the card session.
public struct AuthenticationOutcome: Sendable, Equatable {
    public let result: AuthenticationResultJSON
    public let checks: [RPCheck]
    /// The registration after the run: `signCount` and `lastUsedAt` updated when the checks passed.
    public let credential: StoredCredential
    public let saveError: String?

    public var passed: Bool { checks.allSatisfy(\.passed) && saveError == nil }
}
