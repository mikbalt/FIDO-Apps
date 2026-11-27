/// Settings shared by every `FIDOSimulator` scenario.
public struct FIDOSimConfiguration: Sendable {
    public var lengthForm: LengthForm
    /// P1 = `80` in NFCCTAP_MSG. Off: on NFC the tap already counts as user presence. Mock replays set it
    /// from the fixture so the bytes match.
    public var getResponseSupported: Bool
    /// The card label recorded by `diagnostics`, which takes no label of its own.
    public var cardLabel: String
    public var app: AppInfo
    public var device: DeviceInfo
    /// Where PINs are kept when the tester turns "Store PIN" on. Reset deletes the card's stored PIN.
    public var pinStore: (any PINStore)?
    /// Called with the card label after a successful reset. The app marks that card's registrations invalid.
    public var onCardReset: @Sendable (String) -> Void
    /// Where registrations are kept. `nil`: registrations are checked but not saved.
    public var credentialStore: CredentialStore?
    /// Where every run's trace is saved. `nil`: runs are not saved.
    public var traceStore: TraceStore?
    /// The local RP that makes the challenges and checks the results (brief 03).
    public var relyingParty: LocalRelyingParty
    /// Randomness for PIN protocol 2. Injectable for tests.
    public var pinRandomness: any PinUvAuthRandomness

    public init(
        lengthForm: LengthForm = .short,
        getResponseSupported: Bool = false,
        cardLabel: String = "",
        app: AppInfo = .current(),
        device: DeviceInfo = .current,
        pinStore: (any PINStore)? = nil,
        onCardReset: @escaping @Sendable (String) -> Void = { _ in },
        credentialStore: CredentialStore? = nil,
        traceStore: TraceStore? = nil,
        relyingParty: LocalRelyingParty = LocalRelyingParty(),
        pinRandomness: any PinUvAuthRandomness = SystemPinUvAuthRandomness()
    ) {
        self.lengthForm = lengthForm
        self.getResponseSupported = getResponseSupported
        self.cardLabel = cardLabel
        self.app = app
        self.device = device
        self.pinStore = pinStore
        self.onCardReset = onCardReset
        self.credentialStore = credentialStore
        self.traceStore = traceStore
        self.relyingParty = relyingParty
        self.pinRandomness = pinRandomness
    }

    var channelOptions: ChannelOptions {
        ChannelOptions(lengthForm: lengthForm, getResponseSupported: getResponseSupported)
    }
}
