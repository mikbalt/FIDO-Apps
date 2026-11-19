/// An error that knows how it appears in a trace outcome.
public protocol TraceErrorConvertible: Error {
    var traceError: TraceError { get }
}
