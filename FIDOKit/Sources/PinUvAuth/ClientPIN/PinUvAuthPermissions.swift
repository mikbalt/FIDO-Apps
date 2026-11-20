/// Permissions for getPinUvAuthTokenUsingPinWithPermissions (CTAP 2.1 §6.5.5.7).
public struct PinUvAuthPermissions: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let makeCredential = PinUvAuthPermissions(rawValue: 0x01)
    public static let getAssertion = PinUvAuthPermissions(rawValue: 0x02)
    public static let credentialManagement = PinUvAuthPermissions(rawValue: 0x04)
    public static let bioEnrollment = PinUvAuthPermissions(rawValue: 0x08)
    public static let largeBlobWrite = PinUvAuthPermissions(rawValue: 0x10)
    public static let authenticatorConfig = PinUvAuthPermissions(rawValue: 0x20)
}
