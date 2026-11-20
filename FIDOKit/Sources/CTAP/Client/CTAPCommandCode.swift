/// CTAP2 command bytes (study guide §4).
public enum CTAPCommandCode: UInt8, Sendable, CaseIterable {
    case makeCredential = 0x01
    case getAssertion = 0x02
    case getInfo = 0x04
    case clientPIN = 0x06
    case reset = 0x07
    case getNextAssertion = 0x08
    case bioEnrollment = 0x09
    case credentialManagement = 0x0A
    case selection = 0x0B
    case largeBlobs = 0x0C
    case config = 0x0D
    case prototypeBioEnrollment = 0x40
    case prototypeCredentialManagement = 0x41
}
