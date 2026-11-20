import FIDOKit
import SwiftUI

/// Engineering screens, until the final UI arrives from the UI/UX team.
struct LabView: View {
    @State private var diagnostics: DiagnosticsViewModel
    @State private var changePIN: ChangePINViewModel
    @State private var setPIN: SetPINViewModel
    @State private var reset: ResetViewModel

    init(environment: LabEnvironment) {
        _diagnostics = State(initialValue: DiagnosticsViewModel(environment: environment))
        _changePIN = State(initialValue: ChangePINViewModel(environment: environment))
        _setPIN = State(initialValue: SetPINViewModel(environment: environment))
        _reset = State(initialValue: ResetViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Card") {
                    NavigationLink("Diagnostics") { DiagnosticsView(model: diagnostics) }
                }
                Section("PIN and reset") {
                    NavigationLink("Change PIN") { ChangePINView(model: changePIN) }
                    NavigationLink("Set PIN") { SetPINView(model: setPIN) }
                    NavigationLink("Reset") { ResetView(model: reset) }
                }
            }
            .navigationTitle("Lab")
        }
    }
}

#Preview {
    LabView(environment: AppContainer().environment)
}
