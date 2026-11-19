/// Why a session ended. See `docs/trace-format.md` for the list of values.
///
/// A closed set, except that values this version does not know decode as `.unknown(raw)` and encode back
/// unchanged, so traces from later versions still load.
public enum SessionEndReason: Hashable, Sendable {
    // Scenario outcomes.

    /// The scenario ran to the end.
    case completed
    /// SELECT did not return 9000 with a known FIDO version string.
    case selectFailed
    /// GetInfo returned 6D00: the card only speaks CTAP1/U2F.
    case ctap1Only
    /// GetInfo returned another status word, or a non-zero CTAP status.
    case getInfoFailed
    /// The run's task was cancelled (the app's Cancel button).
    case cancelled

    // Transport failures, one per `CardError` case.

    /// `CardError.userCancelled`: the user dismissed the system NFC sheet.
    case userCancelled
    /// `CardError.sessionTimeout`
    case sessionTimeout
    /// `CardError.tagConnectionLost`
    case tagConnectionLost
    /// `CardError.nfcUnavailable`
    case nfcUnavailable
    /// `CardError.invalidAPDU`
    case invalidAPDU
    /// `CardError.notConnected`
    case notConnected
    /// `CardError.underlying`: a transport error with no case of its own.
    case transportError

    // Everything else.

    /// Any other error, e.g. a channel protocol error or a mock script mismatch.
    case error
    /// A value written by a later version.
    case unknown(String)

    /// Every known value, in documentation order.
    public static let known: [SessionEndReason] = [
        .completed, .selectFailed, .ctap1Only, .getInfoFailed, .cancelled,
        .userCancelled, .sessionTimeout, .tagConnectionLost, .nfcUnavailable, .invalidAPDU, .notConnected,
        .transportError, .error,
    ]

    public init(rawValue: String) {
        self = Self.known.first { $0.rawValue == rawValue } ?? .unknown(rawValue)
    }

    /// The reason for a transport failure.
    public init(_ error: CardError) {
        switch error {
        case .userCancelled: self = .userCancelled
        case .sessionTimeout: self = .sessionTimeout
        case .tagConnectionLost: self = .tagConnectionLost
        case .nfcUnavailable: self = .nfcUnavailable
        case .invalidAPDU: self = .invalidAPDU
        case .notConnected: self = .notConnected
        case .underlying: self = .transportError
        }
    }

    public var rawValue: String {
        switch self {
        case .completed: "completed"
        case .selectFailed: "selectFailed"
        case .ctap1Only: "ctap1Only"
        case .getInfoFailed: "getInfoFailed"
        case .cancelled: "cancelled"
        case .userCancelled: "userCancelled"
        case .sessionTimeout: "sessionTimeout"
        case .tagConnectionLost: "tagConnectionLost"
        case .nfcUnavailable: "nfcUnavailable"
        case .invalidAPDU: "invalidAPDU"
        case .notConnected: "notConnected"
        case .transportError: "transportError"
        case .error: "error"
        case let .unknown(raw): raw
        }
    }

    public var displayName: String {
        switch self {
        case .completed: "Completed"
        case .selectFailed: "SELECT failed"
        case .ctap1Only: "CTAP1-only card"
        case .getInfoFailed: "GetInfo failed"
        case .cancelled: "Cancelled"
        case .userCancelled: "Cancelled in NFC sheet"
        case .sessionTimeout: "NFC session timed out"
        case .tagConnectionLost: "Card connection lost"
        case .nfcUnavailable: "NFC unavailable"
        case .invalidAPDU: "Invalid APDU"
        case .notConnected: "Not connected"
        case .transportError: "Transport error"
        case .error: "Error"
        case let .unknown(raw): raw
        }
    }
}

extension SessionEndReason: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
