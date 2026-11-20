import FIDOKit
import Foundation
import Observation

@MainActor
@Observable
final class SetPINViewModel: PINScreenModel {
    var cardLabel = "Lab card A"
    var source: PINSource = .defaultPIN
    var customPIN = ""
    var storePIN = false
    private(set) var setupError: String?

    let runner = ScenarioRunModel()
    let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
    }

    var canRun: Bool {
        !runner.isRunning && !needsNFC && !cardLabel.isEmpty && resolve(source, custom: customPIN) != nil
    }

    func run() {
        guard canRun, let pin = resolve(source, custom: customPIN) else { return }
        setupError = nil
        let simulator: FIDOSimulator
        do {
            simulator = try makeSimulator()
        } catch {
            setupError = error.localizedDescription
            return
        }
        let label = cardLabel
        let store = storePIN
        runner.run({ progress in
            let result = await simulator.setPIN(pin, cardLabel: label, progress: progress)
            return (result.trace, result.error)
        }, onSuccess: { [weak self] in
            guard store else { return }
            do {
                try self?.environment.pinStore.savePIN(pin, for: label)
            } catch {
                self?.setupError = error.localizedDescription
            }
        })
    }
}
