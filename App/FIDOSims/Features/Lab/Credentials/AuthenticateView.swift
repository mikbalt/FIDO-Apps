import FIDOKit
import SwiftUI

/// Authenticate: SELECT, GetInfo, key agreement, PIN token, GetAssertion, then the RP checks.
struct AuthenticateView: View {
    @Bindable var model: AuthenticateViewModel

    var body: some View {
        ScenarioScreen(title: "Authenticate", model: model.runner, runTitle: "Authenticate", canRun: model.canRun, run: model.run) {
            Section {
                if model.credentials.isEmpty {
                    Text("No registrations yet. Use Register first.").foregroundStyle(.secondary)
                } else {
                    Picker("Registration", selection: $model.selectedID) {
                        ForEach(model.credentials) { credential in
                            Text("\(credential.username) · \(credential.cardLabel)\(credential.invalidated ? " (invalidated)" : "")")
                                .tag(Optional(credential.id))
                        }
                    }
                }
                if let warning = model.selectionWarning {
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                TextField("Card label", text: $model.cardLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PINInputSection(
                    title: "PIN", source: $model.pinSource, custom: $model.customPIN,
                    sources: PINSource.allCases, hasStoredPIN: model.hasStoredPIN
                )
            } header: {
                Text("Setup")
            } footer: {
                PINScreenFooter(needsNFC: model.needsNFC, setupError: model.setupError,
                                note: "A wrong PIN costs one retry.")
            }
        } results: {
            if let outcome = model.outcome, let trace = model.runner.latestTrace {
                ChecksListView(checks: outcome.checks, saveError: outcome.saveError)
                CredentialLinksSection(
                    credential: outcome.credential, details: model.environment.credentialStore.details(for: outcome.credential.id),
                    traceID: trace.id, environment: model.environment)
            }
        }
        .onAppear { model.reload() }
    }
}
