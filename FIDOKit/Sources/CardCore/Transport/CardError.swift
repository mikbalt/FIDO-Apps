import Foundation

/// Transport-level failures, shared by every `CardTransport`.
public enum CardError: Error, Sendable {
    case userCancelled
    /// The system ended the reader session (the iOS 60 s limit).
    case sessionTimeout
    case tagConnectionLost
    case nfcUnavailable
    /// The command bytes could not be wrapped as an APDU (for example, a refused extended encoding).
    case invalidAPDU
    /// `transmit` was called without an open session and connected card.
    case notConnected
    case underlying(any Error)
}

extension CardError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .userCancelled: "The NFC session was cancelled."
        case .sessionTimeout: "The NFC session timed out."
        case .tagConnectionLost: "The connection to the card was lost. Keep the card in place."
        case .nfcUnavailable: "NFC reading is not available on this device."
        case .invalidAPDU: "The command could not be sent as an APDU."
        case .notConnected: "No card is connected."
        case let .underlying(error): error.localizedDescription
        }
    }
}

extension CardError: TraceErrorConvertible {
    /// `code` is the matching `sessionEnded.reason`, e.g. `tagConnectionLost`.
    public var traceError: TraceError {
        let reason = SessionEndReason(self)
        let name: String = switch self {
        case .userCancelled: "USER_CANCELLED"
        case .sessionTimeout: "SESSION_TIMEOUT"
        case .tagConnectionLost: "TAG_CONNECTION_LOST"
        case .nfcUnavailable: "NFC_UNAVAILABLE"
        case .invalidAPDU: "INVALID_APDU"
        case .notConnected: "NOT_CONNECTED"
        case .underlying: "TRANSPORT_ERROR"
        }
        return TraceError(domain: .transport, code: reason.rawValue, name: name, message: errorDescription ?? name)
    }
}
