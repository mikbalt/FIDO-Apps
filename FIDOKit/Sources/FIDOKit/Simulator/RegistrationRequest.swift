/// What `FIDOSimulator.register` needs.
public struct RegistrationRequest: Sendable, Equatable {
    public var username: String
    public var pin: String
    public var cardLabel: String
    /// Ask for a discoverable credential (`rk`).
    public var residentKey: Bool

    public init(username: String, pin: String, cardLabel: String, residentKey: Bool = false) {
        self.username = username
        self.pin = pin
        self.cardLabel = cardLabel
        self.residentKey = residentKey
    }
}
