import Foundation

public enum MockTransportError: Error, Equatable, Sendable {
    /// The sent command differs from the next scripted `tx`.
    case unexpectedCommand(index: Int, label: String, expected: Data, actual: Data)
    /// A command was sent after the script ran out.
    case scriptExhausted(actual: Data)
    /// The trace has redacted exchanges, whose bytes are not in the file, so it cannot be replayed.
    /// `index` and `label` are those of the first redacted exchange.
    case redactedTrace(redactedCount: Int, index: Int, label: String)
    case notOpen
}

extension MockTransportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .unexpectedCommand(index, label, expected, actual):
            "Mock exchange \(index) (\(label)) does not match the script.\n"
                + "Expected: \(Hex.format(expected))\nActual:   \(Hex.format(actual))"
        case let .scriptExhausted(actual):
            "Mock script has no more exchanges. Unexpected command: \(Hex.format(actual))"
        case let .redactedTrace(redactedCount, index, label):
            "This trace cannot be replayed: \(redactedCount) exchange\(redactedCount == 1 ? " is" : "s are") redacted, "
                + "starting with exchange \(index) (\(label)), so the bytes to compare and answer with are missing. "
                + "Replay needs an unredacted trace."
        case .notOpen:
            "The mock session is not open."
        }
    }
}

extension MockTransportError: TraceErrorConvertible {
    public var traceError: TraceError {
        let (code, name): (String, String) = switch self {
        case .unexpectedCommand: ("unexpectedCommand", "MOCK_UNEXPECTED_COMMAND")
        case .scriptExhausted: ("scriptExhausted", "MOCK_SCRIPT_EXHAUSTED")
        case .redactedTrace: ("redactedTrace", "MOCK_REDACTED_TRACE")
        case .notOpen: ("notOpen", "MOCK_NOT_OPEN")
        }
        return TraceError(domain: .internal, code: code, name: name, message: errorDescription ?? name)
    }
}
