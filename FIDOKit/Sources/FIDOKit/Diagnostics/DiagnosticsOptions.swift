/// Settings for a diagnostics run.
public struct DiagnosticsOptions: Sendable {
    public var lengthForm: LengthForm
    public var getResponseSupported: Bool
    public var cardLabel: String
    public var app: AppInfo
    public var device: DeviceInfo
    public var statusPollInterval: Duration
    public var statusUpdateTimeout: Duration

    public init(
        lengthForm: LengthForm = .short,
        getResponseSupported: Bool = false,
        cardLabel: String = "",
        app: AppInfo = .current(),
        device: DeviceInfo = .current,
        statusPollInterval: Duration = .zero,
        statusUpdateTimeout: Duration = .seconds(30)
    ) {
        self.lengthForm = lengthForm
        self.getResponseSupported = getResponseSupported
        self.cardLabel = cardLabel
        self.app = app
        self.device = device
        self.statusPollInterval = statusPollInterval
        self.statusUpdateTimeout = statusUpdateTimeout
    }

    var channelOptions: ChannelOptions {
        ChannelOptions(
            lengthForm: lengthForm,
            getResponseSupported: getResponseSupported,
            statusPollInterval: statusPollInterval,
            statusUpdateTimeout: statusUpdateTimeout
        )
    }
}
