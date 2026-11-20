import FIDOKit
import Foundation
import Observation

@MainActor
@Observable
final class ResetViewModel: PINScreenModel {
    var cardLabel = "Lab card A"
    /// The tester types the card label again to confirm.
    var confirmation = ""
    private(set) var setupError: String?

    let runner = ScenarioRunModel()
    let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
    }

    var isConfirmed: Bool { !cardLabel.isEmpty && confirmation == cardLabel }

    var canRun: Bool { !runner.isRunning && !needsNFC && isConfirmed }

    func run() {
        guard canRun else { return }
        setupError = nil
        let simulator: FIDOSimulator
        do {
            simulator = try makeSimulator()
        } catch {
            setupError = error.localizedDescription
            return
        }
        let label = cardLabel
        runner.run({ progress in
            let result = await simulator.reset(confirmedCardLabel: label, progress: progress)
            return (result.trace, result.error)
        }, onSuccess: { [weak self] in
            self?.confirmation = ""
        })
    }
}
