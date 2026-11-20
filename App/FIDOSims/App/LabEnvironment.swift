import FIDOKit

/// What Lab view models need from the app. Built by `AppContainer`; view models only see `CardTransport`.
struct LabEnvironment: Sendable {
    let isNFCAvailable: Bool
    let fixtures: [MockFixture]
    let makeTransport: @MainActor (TransportSelection) throws -> any CardTransport
    let pinStore: any PINStore
    /// Brief 03 marks the card's registrations invalid here.
    let onCardReset: @Sendable (String) -> Void

    func configuration(cardLabel: String = "", lengthForm: LengthForm = .short, getResponseSupported: Bool = false) -> FIDOSimConfiguration {
        FIDOSimConfiguration(
            lengthForm: lengthForm, getResponseSupported: getResponseSupported, cardLabel: cardLabel,
            pinStore: pinStore, onCardReset: onCardReset
        )
    }
}
