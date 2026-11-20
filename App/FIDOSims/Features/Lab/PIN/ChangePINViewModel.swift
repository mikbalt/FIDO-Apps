import FIDOKit
import Foundation
import Observation

@MainActor
@Observable
final class ChangePINViewModel: PINScreenModel {
    var cardLabel = "Lab card A"
    var currentSource: PINSource = .defaultPIN
    var customCurrent = ""
    var newPIN = ""
    var storePIN = false
    private(set) var setupError: String?

    let runner = ScenarioRunModel()
    let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
    }

    var canRun: Bool {
        !runner.isRunning && !needsNFC && !cardLabel.isEmpty && !newPIN.isEmpty
            && resolve(currentSource, custom: customCurrent) != nil
    }

    func run() {
        guard canRun, let current = resolve(currentSource, custom: customCurrent) else { return }
        setupError = nil
        let simulator: FIDOSimulator
        do {
            simulator = try makeSimulator()
        } catch {
            setupError = error.localizedDescription
            return
        }
        let new = newPIN
        let label = cardLabel
        let store = storePIN
        runner.run({ progress in
            let result = await simulator.changePIN(current: current, new: new, cardLabel: label, progress: progress)
            return (result.trace, result.error)
        }, onSuccess: { [weak self] in
            guard store else { return }
            do {
                try self?.environment.pinStore.savePIN(new, for: label)
            } catch {
                self?.setupError = error.localizedDescription
            }
        })
    }
}
