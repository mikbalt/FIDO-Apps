import Security
import Foundation

public struct KeychainPINStoreError: Error, Equatable, Sendable {
    public let status: OSStatus
}

extension KeychainPINStoreError: LocalizedError {
    public var errorDescription: String? {
        let detail = SecCopyErrorMessageString(status, nil).map { $0 as String } ?? "OSStatus \(status)"
        return "The PIN could not be stored in the Keychain: \(detail)"
    }
}
