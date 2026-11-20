import FIDOKit
import Foundation

/// What the three PIN/reset screens share: the card label, NFC availability and the PIN store.
@MainActor
protocol PINScreenModel: AnyObject {
    var environment: LabEnvironment { get }
    var cardLabel: String { get }
}

extension PINScreenModel {
    /// PIN and reset scenarios need a real card: there is no mock for them.
    var needsNFC: Bool { !environment.isNFCAvailable }

    var hasStoredPIN: Bool {
        !cardLabel.isEmpty && ((try? environment.pinStore.loadPIN(for: cardLabel)) ?? nil) != nil
    }

    func resolve(_ source: PINSource, custom: String) -> String? {
        switch source {
        case .defaultPIN: PINSource.defaultValue
        case .custom: custom.isEmpty ? nil : custom
        case .stored: (try? environment.pinStore.loadPIN(for: cardLabel)) ?? nil
        }
    }

    func makeSimulator() throws -> FIDOSimulator {
        FIDOSimulator(transport: try environment.makeTransport(.nfc), configuration: environment.configuration())
    }
}
