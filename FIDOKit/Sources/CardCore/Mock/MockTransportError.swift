import Foundation

public enum MockTransportError: Error, Equatable, Sendable {
    /// The sent command differs from the next scripted `tx`.
    case unexpectedCommand(index: Int, label: String, expected: Data, actual: Data)
    /// A command was sent after the script ran out.
    case scriptExhausted(actual: Data)
    /// The fixture has redacted exchanges, so it cannot be replayed.
    case redactedFixture(index: Int)
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
        case let .redactedFixture(index):
            "Exchange \(index) of the fixture is redacted and cannot be replayed."
        case .notOpen:
            "The mock session is not open."
        }
    }
}
