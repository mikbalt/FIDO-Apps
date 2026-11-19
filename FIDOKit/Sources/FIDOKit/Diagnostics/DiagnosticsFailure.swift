import Foundation

/// A diagnostics run failed after the card was connected. Carries the partial trace.
public struct DiagnosticsFailure: Error {
    public let underlying: any Error
    /// Every exchange completed before the failure, ended with `cancelled`, a `CardError` reason or `error`.
    public let trace: Trace

    public init(underlying: any Error, trace: Trace) {
        self.underlying = underlying
        self.trace = trace
    }

    /// The run was cancelled by the task or by the user, rather than failing.
    public var isCancellation: Bool { Self.isCancellation(underlying) }

    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if case CardError.userCancelled = error { return true }
        return false
    }
}

extension DiagnosticsFailure: LocalizedError {
    public var errorDescription: String? {
        underlying.localizedDescription
    }
}
