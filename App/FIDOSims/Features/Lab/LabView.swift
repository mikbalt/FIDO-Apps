import FIDOKit
import SwiftUI

/// Engineering screens, until the final UI arrives from the UI/UX team.
struct LabView: View {
    @State private var diagnostics: DiagnosticsViewModel
    @State private var changePIN: ChangePINViewModel
    @State private var setPIN: SetPINViewModel
    @State private var reset: ResetViewModel
    @State private var registrations: RegistrationsViewModel
    @State private var register: RegisterViewModel
    @State private var authenticate: AuthenticateViewModel
    @State private var history: HistoryViewModel

    init(environment: LabEnvironment) {
        _diagnostics = State(initialValue: DiagnosticsViewModel(environment: environment))
        _changePIN = State(initialValue: ChangePINViewModel(environment: environment))
        _setPIN = State(initialValue: SetPINViewModel(environment: environment))
        _reset = State(initialValue: ResetViewModel(environment: environment))
        _history = State(initialValue: HistoryViewModel(store: environment.traceStore))
        _register = State(initialValue: RegisterViewModel(environment: environment))
        _authenticate = State(initialValue: AuthenticateViewModel(environment: environment))
        _registrations = State(initialValue: RegistrationsViewModel(store: environment.credentialStore))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Card") {
                    NavigationLink("Diagnostics") { DiagnosticsView(model: diagnostics) }
                }
                Section("Register and authenticate") {
                    NavigationLink("Register") { RegisterView(model: register) }
                    NavigationLink("Authenticate") { AuthenticateView(model: authenticate) }
                }
                Section("Registrations") {
                    NavigationLink("Registrations") { RegistrationsView(model: registrations) }
                }
                Section("History") {
                    NavigationLink("History") { HistoryView(model: history) }
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
