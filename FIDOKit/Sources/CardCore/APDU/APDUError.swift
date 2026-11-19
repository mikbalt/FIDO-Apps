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
