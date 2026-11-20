import CardCore
import Foundation

/// A PIN refused before anything is sent to the card.
public enum PINError: Error, Equatable, Sendable {
    /// Fewer Unicode code points than `max(4, minPINLength)`.
    case tooShort(minimum: Int)
    /// More than 63 UTF-8 bytes.
    case tooLong
    /// The card already has a PIN (Set PIN), or has none (Change PIN).
    case pinAlreadySet
    /// The card does not support ClientPIN.
    case clientPINUnsupported
    /// GetInfo does not list PIN protocol 2. Brief 02 says stop and ask, so this is not worked around.
    case pinProtocol2Unsupported(listed: [Int])
}

extension PINError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .tooShort(minimum): "The PIN must have at least \(minimum) characters."
        case .tooLong: "The PIN must be at most 63 bytes in UTF-8."
        case .pinAlreadySet: "This card already has a PIN. Use Change PIN, or reset the card first."
        case .clientPINUnsupported: "This card does not support a PIN (no clientPin option in GetInfo)."
        case let .pinProtocol2Unsupported(listed):
            "This card does not support PIN protocol 2 (it lists \(listed.isEmpty ? "none" : listed.map(String.init).joined(separator: ", ")))."
        }
    }
}

extension PINError: TraceErrorConvertible {
    public var traceError: TraceError {
        let (code, name): (String, String) = switch self {
        case .tooShort: ("pinTooShort", "PIN_TOO_SHORT")
        case .tooLong: ("pinTooLong", "PIN_TOO_LONG")
        case .pinAlreadySet: ("pinAlreadySet", "PIN_ALREADY_SET")
        case .clientPINUnsupported: ("clientPINUnsupported", "CLIENT_PIN_UNSUPPORTED")
        case .pinProtocol2Unsupported: ("pinProtocol2Unsupported", "PIN_PROTOCOL_2_UNSUPPORTED")
        }
        return TraceError(domain: .validation, code: code, name: name, message: errorDescription ?? name)
    }
}
