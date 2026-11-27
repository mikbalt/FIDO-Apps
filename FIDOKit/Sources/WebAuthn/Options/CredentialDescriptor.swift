import Foundation

/// An entry of `allowCredentials`.
public struct CredentialDescriptor: Codable, Sendable, Equatable {
    public var type: String
    public var id: Data
    public var transports: [String]?

    public init(type: String = "public-key", id: Data, transports: [String]? = nil) {
        self.type = type
        self.id = id
        self.transports = transports
    }
}
