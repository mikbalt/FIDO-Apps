/// How the whole scenario ended, as the user saw it.
public struct TraceOutcome: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable {
        case success, failure, cancelled
    }

    public var status: Status
    /// Set for `failure`; `nil` otherwise.
    public var error: TraceError?

    public init(status: Status, error: TraceError? = nil) {
        self.status = status
        self.error = error
    }

    public static let success = TraceOutcome(status: .success)
    public static let cancelled = TraceOutcome(status: .cancelled)

    public static func failure(_ error: TraceError) -> TraceOutcome {
        TraceOutcome(status: .failure, error: error)
    }
}
