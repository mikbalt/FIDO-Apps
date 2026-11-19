/// Why a session ended. An open set of strings, so traces from other producers still decode.
public struct SessionEndReason: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// The scenario ran to the end.
    public static let completed = SessionEndReason(rawValue: "completed")
    /// SELECT did not return 9000 with a known FIDO version string.
    public static let selectFailed = SessionEndReason(rawValue: "selectFailed")
    /// GetInfo returned 6D00: the card only speaks CTAP1/U2F.
    public static let ctap1Only = SessionEndReason(rawValue: "ctap1Only")
    /// GetInfo returned another status word, or a non-zero CTAP status.
    public static let getInfoFailed = SessionEndReason(rawValue: "getInfoFailed")
    /// The run was cancelled by the user or the task.
    public static let cancelled = SessionEndReason(rawValue: "cancelled")
    /// A transport or protocol error ended the run.
    public static let error = SessionEndReason(rawValue: "error")

    public var displayName: String {
        switch self {
        case .completed: "Completed"
        case .selectFailed: "SELECT failed"
        case .ctap1Only: "CTAP1-only card"
        case .getInfoFailed: "GetInfo failed"
        case .cancelled: "Cancelled"
        case .error: "Error"
        default: rawValue
        }
    }
}
