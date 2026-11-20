import FIDOKit
import Foundation
import Observation

/// SELECT + GetInfo through the facade, over NFC or a mock fixture.
@MainActor
@Observable
final class DiagnosticsViewModel {
    var transportChoice: TransportChoice
    var selectedFixtureID: MockFixture.ID?
    var lengthForm: LengthForm = .short
    var cardLabel = "Lab card A"
    var realtimeReplay = false
    /// Set when the run could not start, e.g. the transport could not be built.
    private(set) var setupError: String?

    let runner = ScenarioRunModel()
    private let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
        transportChoice = environment.isNFCAvailable ? .nfc : .mock
        selectedFixtureID = environment.fixtures.first?.id
    }

    var fixtures: [MockFixture] { environment.fixtures }

    /// Mock is the only option in the Simulator or without NFC hardware.
    var isMockForced: Bool { !environment.isNFCAvailable }

    var selectedFixture: MockFixture? {
        fixtures.first { $0.id == selectedFixtureID }
    }

    var canRun: Bool {
        !runner.isRunning && (transportChoice == .nfc || selectedFixture != nil)
    }

    func run() {
        guard canRun else { return }
        setupError = nil
        let selection: TransportSelection
        var configuration = environment.configuration(cardLabel: cardLabel, lengthForm: lengthForm)
        switch transportChoice {
        case .nfc:
            selection = .nfc
        case .mock:
            guard let fixture = selectedFixture else { return }
            selection = .mock(fixture, realtime: realtimeReplay)
            // A replay only matches when it sends the same bytes as the recording.
            configuration.lengthForm = fixture.trace.options.lengthForm
            configuration.getResponseSupported = fixture.trace.options.getResponseSupported
            if cardLabel.isEmpty {
                configuration.cardLabel = fixture.trace.card.label
            }
        }

        let transport: any CardTransport
        do {
            transport = try environment.makeTransport(selection)
        } catch {
            setupError = error.localizedDescription
            return
        }
        let simulator = FIDOSimulator(transport: transport, configuration: configuration)
        runner.run { progress in
            let result = await simulator.diagnostics(progress: progress)
            return (result.trace, result.error)
        }
    }
}
