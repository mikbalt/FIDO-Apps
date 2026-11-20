import Foundation

/// Why a scenario failed: the same domain, code, name and message as the trace's `outcome.error`.
public struct FIDOSimError: Error, Sendable, Equatable {
    public let domain: TraceErrorDomain
    public let code: String
    public let name: String
    public let message: String

    public init(_ error: TraceError) {
        domain = error.domain
        code = error.code
        name = error.name
        message = error.message
    }

    public var traceError: TraceError {
        TraceError(domain: domain, code: code, name: name, message: message)
    }
}

extension FIDOSimError: LocalizedError {
    public var errorDescription: String? { message }
}
