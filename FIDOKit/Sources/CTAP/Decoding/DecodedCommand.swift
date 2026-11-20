import CardCore

/// One logical command of a trace, decoded for the Decoded view.
public struct DecodedCommand: Sendable, Equatable, Identifiable {
    public let commandIndex: Int
    public let label: String
    /// The final status word.
    public let sw: StatusWord
    public let ctapStatus: UInt8?
    public let sensitive: Bool
    /// A one-line meaning, as in the mockup log, e.g. "Capabilities received".
    public let summary: String
    /// The CTAP request parameters. `nil` for non-CTAP commands, empty requests and sensitive commands.
    public let request: CBORValue?
    /// The CTAP response body. `nil` when empty, not CTAP, or sensitive.
    public let response: CBORValue?

    public var id: Int { commandIndex }

    /// The command succeeded: SW `9000` and, for CTAP commands, status `00`.
    public var succeeded: Bool { sw.isSuccess && (ctapStatus ?? 0) == 0 }
}
