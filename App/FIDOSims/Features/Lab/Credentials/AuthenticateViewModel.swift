import FIDOKit
import Foundation
import Observation

/// Authenticate with a stored registration: GetAssertion, then the RP's checks and the counter update.
@MainActor
@Observable
final class AuthenticateViewModel: PINScreenModel {
    var selectedID: StoredCredential.ID? {
        didSet {
            // The card label follows the registration, until the tester edits it.
            if let credential = selectedCredential { cardLabel = credential.cardLabel }
        }
    }
    var cardLabel = "Lab card A"
    var pinSource: PINSource = .defaultPIN
    var customPIN = ""
    private(set) var credentials: [StoredCredential] = []
    private(set) var setupError: String?
    private(set) var outcome: AuthenticationOutcome?

    let runner = ScenarioRunModel()
    let environment: LabEnvironment

    init(environment: LabEnvironment) {
        self.environment = environment
        reload()
    }

    var selectedCredential: StoredCredential? {
        credentials.first { $0.id == selectedID }
    }

    /// Invalidated registrations can still be picked: the request is sent anyway, to see the card's answer.
    var selectionWarning: String? {
        selectedCredential?.invalidated == true
            ? "This registration is invalidated: its card was reset. The request is still sent, so you can see the card's answer."
            : nil
    }

    func reload() {
        credentials = environment.credentialStore.all()
        if selectedCredential == nil {
            selectedID = credentials.first?.id
        }
    }

    var canRun: Bool {
        !runner.isRunning && !needsNFC && selectedCredential != nil && !cardLabel.isEmpty
            && resolve(pinSource, custom: customPIN) != nil
    }

    func run() {
        guard canRun, let credential = selectedCredential, let pin = resolve(pinSource, custom: customPIN) else { return }
        setupError = nil
        outcome = nil
        let simulator: FIDOSimulator
        do {
            simulator = try makeSimulator()
        } catch {
            setupError = error.localizedDescription
            return
        }
        let request = AuthenticationRequest(credential: credential, pin: pin, cardLabel: cardLabel)
        runner.run({ [weak self] progress in
            let result = await simulator.authenticate(request, progress: progress)
            await MainActor.run { self?.outcome = result.value }
            return (result.trace, result.error)
        }, onSuccess: { [weak self] in
            self?.reload()
        })
    }
}
