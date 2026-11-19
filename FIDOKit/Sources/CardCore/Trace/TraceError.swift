/// The error of a failed scenario.
///
/// `code` is a string whose form depends on the domain (see `docs/trace-format.md`): a status word
/// (`6A82`), a CTAP status byte (`0x31`), or a stable identifier (`tagConnectionLost`, `requestTooLarge`).
public struct TraceError: Codable, Sendable, Equatable {
    public var domain: TraceErrorDomain
    public var code: String
    /// A stable symbolic name, e.g. `CTAP2_ERR_PIN_INVALID` or `FILE_NOT_FOUND`.
    public var name: String
    /// Human-readable description.
    public var message: String

    public init(domain: TraceErrorDomain, code: String, name: String, message: String) {
        self.domain = domain
        self.code = code
        self.name = name
        self.message = message
    }

    /// The trace error for any thrown error: its own mapping if it is `TraceErrorConvertible`,
    /// otherwise an `internal` error named after its type.
    public init(_ error: any Error) {
        if let convertible = error as? any TraceErrorConvertible {
            self = convertible.traceError
        } else {
            let type = String(describing: Swift.type(of: error))
            self.init(domain: .internal, code: type, name: type, message: error.localizedDescription)
        }
    }

    /// A status-word failure in the `iso7816` domain.
    public static func statusWord(_ sw: StatusWord, message: String? = nil) -> TraceError {
        TraceError(
            domain: .iso7816, code: sw.hex, name: sw.symbolicName,
            message: message ?? sw.displayName ?? "SW \(sw.hex)"
        )
    }
}
