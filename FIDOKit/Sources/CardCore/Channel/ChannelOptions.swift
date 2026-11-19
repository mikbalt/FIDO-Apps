/// How an `ISO7816Channel` encodes commands and follows card responses.
public struct ChannelOptions: Sendable, Equatable {
    public var lengthForm: LengthForm
    /// Set P1 = `80` in NFCCTAP_MSG, telling the card the client supports NFCCTAP_GETRESPONSE.
    /// Defaults to true from brief 02 on; cards that refuse it get a P1 = `00` fallback.
    public var getResponseSupported: Bool
    /// Delay between NFCCTAP_GETRESPONSE polls after a `9100` status update.
    public var statusPollInterval: Duration
    /// How long to keep polling after the first `9100` before giving up.
    public var statusUpdateTimeout: Duration

    public init(
        lengthForm: LengthForm = .short,
        getResponseSupported: Bool = true,
        statusPollInterval: Duration = .zero,
        statusUpdateTimeout: Duration = .seconds(30)
    ) {
        self.lengthForm = lengthForm
        self.getResponseSupported = getResponseSupported
        self.statusPollInterval = statusPollInterval
        self.statusUpdateTimeout = statusUpdateTimeout
    }

    /// The options recorded in a trace.
    public var traceOptions: TraceOptions {
        TraceOptions(lengthForm: lengthForm, getResponseSupported: getResponseSupported)
    }
}
