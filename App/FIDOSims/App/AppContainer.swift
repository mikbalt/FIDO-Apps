import FIDOKit
import Foundation

/// Builds the app's object graph. The only place that knows concrete transport types.
@MainActor
final class AppContainer {
    let isNFCAvailable: Bool
    let mockFixtures: [MockFixture]

    init(bundle: Bundle = .main) {
        #if targetEnvironment(simulator)
        isNFCAvailable = false
        #else
        isNFCAvailable = NFCCardTransport.isAvailable
        #endif
        mockFixtures = MockFixture.loadAll(from: bundle)
    }

    func makeTransport(_ selection: TransportSelection) throws -> any CardTransport {
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

    func makeDiagnosticsViewModel() -> DiagnosticsViewModel {
        DiagnosticsViewModel(
            fixtures: mockFixtures,
            isNFCAvailable: isNFCAvailable,
            makeTransport: { selection in try self.makeTransport(selection) }
        )
    }
}
