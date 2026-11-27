/// The outcome of the authentication checks. `newSignCount` is set only when every check passed.
public struct AuthenticationVerification: Sendable, Equatable {
    public let checks: [RPCheck]
    public let newSignCount: UInt32?

    public var passed: Bool { checks.allSatisfy(\.passed) }
}
