/// One named check of the local RP: pass or fail, with a short detail.
public struct RPCheck: Sendable, Equatable, Identifiable {
    public enum Name: String, Sendable, CaseIterable {
        case authenticatorDataParses = "authenticatorData parses"
        case clientDataType = "clientData type"
        case challenge = "Challenge"
        case origin = "Origin"
        case rpIdHash = "rpIdHash"
        case userPresent = "UP flag"
        case userVerified = "UV flag"
        case attestedCredentialData = "AT flag"
        case publicKeyES256 = "Key is ES256"
        case credentialNew = "Credential ID is new"
        case attestationFormat = "Attestation format"
        case credentialKnown = "Credential stored and valid"
        case signature = "Signature"
        case signCount = "signCount"
    }

    public let name: Name
    public let passed: Bool
    public let detail: String

    public var id: Name { name }

    public init(_ name: Name, passed: Bool, _ detail: String) {
        self.name = name
        self.passed = passed
        self.detail = detail
    }
}
