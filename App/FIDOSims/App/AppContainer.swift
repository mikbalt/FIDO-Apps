import FIDOKit
import Foundation

/// Builds the app's object graph. The only place that knows concrete transport and store types.
@MainActor
final class AppContainer {
    let environment: LabEnvironment

    init(bundle: Bundle = .main) {
        #if targetEnvironment(simulator)
        let isNFCAvailable = false
        #else
        let isNFCAvailable = NFCCardTransport.isAvailable
        #endif
        // A credentials file that cannot be read is left alone; the app then works with an empty in-memory store.
        let store = (try? CredentialStore(fileURL: CredentialStore.defaultFileURL())) ?? CredentialStore()
        environment = LabEnvironment(
            isNFCAvailable: isNFCAvailable,
            fixtures: MockFixture.loadAll(from: bundle),
            makeTransport: Self.makeTransport,
            pinStore: KeychainPINStore(),
            credentialStore: store,
            onCardReset: { label in _ = try? store.invalidateCredentials(forCard: label) }
        )
    }

    private static func makeTransport(_ selection: TransportSelection) throws -> any CardTransport {
        switch selection {
        case .nfc:
            #if os(iOS)
            return NFCCardTransport()
            #else
            throw CardError.nfcUnavailable
            #endif
        case let .mock(fixture, realtime):
            return try MockTransport(trace: fixture.trace, realtime: realtime)
        }
    }
}
