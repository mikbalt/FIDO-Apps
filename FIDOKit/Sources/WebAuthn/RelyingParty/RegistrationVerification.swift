import Foundation

/// The outcome of the registration checks. `credential` is set only when every check passed: that is what
/// the store should save.
public struct RegistrationVerification: Sendable, Equatable {
    public struct Credential: Sendable, Equatable {
        public let credentialId: Data
        public let publicKeyCOSE: Data
        public let aaguid: Data
        public let signCount: UInt32
        public let flags: AuthenticatorData.Flags
        public let attestationFormat: String
    }

    public let checks: [RPCheck]
    public let credential: Credential?

    public var passed: Bool { checks.allSatisfy(\.passed) }
}
