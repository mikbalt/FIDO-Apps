/// Which layer an error in a trace outcome comes from.
public enum TraceErrorDomain: String, Codable, Sendable {
    /// The card transport: NFC session, connection, PC/SC.
    case transport
    /// A status word, or an ISO 7816 protocol problem (chaining, `9100` timeout).
    case iso7816
    /// A non-zero CTAP status byte.
    case ctap
    /// Data the app refused: a malformed response, an oversize request, an unknown applet version.
    case validation
    /// The local relying party (from brief 04).
    case rp
    /// A bug or a tooling problem, e.g. a mock script mismatch.
    case `internal`
}
