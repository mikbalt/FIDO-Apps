import Foundation

/// What the RP needs to know about a stored credential. The credential store maps its records to this.
public struct KnownCredential: Sendable, Equatable {
    public let credentialId: Data
    public let publicKeyCOSE: Data
    public let signCount: UInt32
    public let invalidated: Bool

    public init(credentialId: Data, publicKeyCOSE: Data, signCount: UInt32, invalidated: Bool = false) {
        self.credentialId = credentialId
        self.publicKeyCOSE = publicKeyCOSE
        self.signCount = signCount
        self.invalidated = invalidated
    }
}
