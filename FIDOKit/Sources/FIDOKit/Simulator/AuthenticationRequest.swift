/// What `FIDOSimulator.authenticate` needs. An invalidated registration is sent anyway, so the card's
/// answer can be checked after a reset.
public struct AuthenticationRequest: Sendable, Equatable {
    public var credential: StoredCredential
    public var pin: String
    public var cardLabel: String

    public init(credential: StoredCredential, pin: String, cardLabel: String) {
        self.credential = credential
        self.pin = pin
        self.cardLabel = cardLabel
    }
}
