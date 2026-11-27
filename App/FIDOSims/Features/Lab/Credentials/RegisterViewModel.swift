import FIDOKit
import Foundation
import Observation

/// Register: a new credential on the card, checked by the local RP and saved.
@MainActor
@Observable
final class RegisterViewModel: PINScreenModel {
    var username: String
    var cardLabel = "Lab card A"
    var pinSource: PINSource = .defaultPIN
    var customPIN = ""
    var residentKey = false
    private(set) var setupError: String?
    /// The RP's verdict on the latest run. `nil` while running, and after a run that failed at the card.
    private(set) var outcome: RegistrationOutcome?

    let runner = ScenarioRunModel()
    let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
        username = Self.randomUsername()
    }

    /// e.g. `nusa-042`.
    static func randomUsername() -> String {
        "nusa-" + String(format: "%03d", Int.random(in: 0...999))
    }

    func useRandomUsername() {
        username = Self.randomUsername()
    }

    var canRun: Bool {
        !runner.isRunning && !needsNFC && !cardLabel.isEmpty && !username.isEmpty && resolve(pinSource, custom: customPIN) != nil
    }

    func run() {
        guard canRun, let pin = resolve(pinSource, custom: customPIN) else { return }
        setupError = nil
        outcome = nil
        let simulator: FIDOSimulator
        do {
            simulator = try makeSimulator()
        } catch {
            setupError = error.localizedDescription
            return
        }
        let request = RegistrationRequest(username: username, pin: pin, cardLabel: cardLabel, residentKey: residentKey)
        runner.run({ [weak self] progress in
            let result = await simulator.register(request, progress: progress)
            await MainActor.run { self?.outcome = result.value }
            return (result.trace, result.error)
        })
    }
}
