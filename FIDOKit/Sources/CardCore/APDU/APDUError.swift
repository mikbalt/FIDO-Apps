import Foundation

public enum APDUError: Error, Equatable, Sendable {
    /// The command data does not fit the requested length form.
    case dataTooLong(count: Int, form: LengthForm)
    /// Le is outside 1…65536, or larger than the requested form allows.
    case leOutOfRange(le: Int, form: LengthForm)
    /// A response must contain at least SW1 SW2.
    case responseTooShort(count: Int)
}

extension APDUError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .dataTooLong(count, form):
            "Command data of \(count) bytes does not fit \(form) length form (max \(form.maxLc))."
        case let .leOutOfRange(le, form):
            "Le \(le) is out of range for \(form) length form (1…\(form.maxLe))."
        case let .responseTooShort(count):
            "Response of \(count) bytes is shorter than a status word."
        }
    }
}

extension APDUError: TraceErrorConvertible {
    public var traceError: TraceError {
        let (code, name): (String, String) = switch self {
        case .dataTooLong: ("dataTooLong", "APDU_DATA_TOO_LONG")
        case .leOutOfRange: ("leOutOfRange", "APDU_LE_OUT_OF_RANGE")
        case .responseTooShort: ("responseTooShort", "APDU_RESPONSE_TOO_SHORT")
        }
        return TraceError(domain: .validation, code: code, name: name, message: errorDescription ?? name)
    }
}
