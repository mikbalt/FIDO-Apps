/// The GetInfo `options` map (key `0x04`). Absent usually means "not supported"; `false` often means
/// "supported but not configured" (e.g. `clientPin`).
public struct AuthenticatorOptions: Sendable, Equatable {
    /// `true`: a PIN is set. `false`: supported but not set. `nil`: not supported.
    public var clientPin: Bool?
    /// Can store discoverable credentials.
    public var rk: Bool?
    /// Supports the CTAP 2.1 token-with-permissions subcommands.
    public var pinUvAuthToken: Bool?
    /// Non-discoverable credentials can be made without user verification.
    public var makeCredUvNotRqd: Bool?
    /// Every option the card reported, in its order, including the four above.
    public var raw: [CBORMapEntry]

    public init(clientPin: Bool? = nil, rk: Bool? = nil, pinUvAuthToken: Bool? = nil, makeCredUvNotRqd: Bool? = nil,
                raw: [CBORMapEntry] = []) {
        self.clientPin = clientPin
        self.rk = rk
        self.pinUvAuthToken = pinUvAuthToken
        self.makeCredUvNotRqd = makeCredUvNotRqd
        self.raw = raw
    }

    init(map: [CBORMapEntry]) {
        func flag(_ name: String) -> Bool? {
            map.first { $0.key == .text(name) }?.value.boolValue
        }
        self.init(
            clientPin: flag("clientPin"), rk: flag("rk"), pinUvAuthToken: flag("pinUvAuthToken"),
            makeCredUvNotRqd: flag("makeCredUvNotRqd"), raw: map
        )
    }
}
