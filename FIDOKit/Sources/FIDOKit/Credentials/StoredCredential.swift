import Foundation

/// A registration made on a card, as the local RP stores it. [CONTRACT]
public struct StoredCredential: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let credentialId: Data
    public let rpId: String
    public let userHandle: Data
    public let username: String
    public let cardLabel: String
    /// The COSE key exactly as the card sent it.
    public let publicKeyCOSE: Data
    public var signCount: UInt32
    public let discoverable: Bool
    public let attestationFormat: String
    public let createdAt: Date
    public var lastUsedAt: Date?
    /// Set when the card was reset: the card no longer holds the private key.
    public var invalidated: Bool

    public init(
        id: UUID = UUID(), credentialId: Data, rpId: String, userHandle: Data, username: String, cardLabel: String,
        publicKeyCOSE: Data, signCount: UInt32, discoverable: Bool, attestationFormat: String,
        createdAt: Date = .now, lastUsedAt: Date? = nil, invalidated: Bool = false
    ) {
        self.id = id
        self.credentialId = credentialId
        self.rpId = rpId
        self.userHandle = userHandle
        self.username = username
        self.cardLabel = cardLabel
        self.publicKeyCOSE = publicKeyCOSE
        self.signCount = signCount
        self.discoverable = discoverable
        self.attestationFormat = attestationFormat
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.invalidated = invalidated
    }
}
