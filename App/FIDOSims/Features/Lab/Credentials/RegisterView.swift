import FIDOKit
import SwiftUI

/// Register: SELECT, GetInfo, key agreement, PIN token, MakeCredential, then the RP checks.
struct RegisterView: View {
    @Bindable var model: RegisterViewModel

    var body: some View {
        ScenarioScreen(title: "Register", model: model.runner, runTitle: "Register", canRun: model.canRun, run: model.run) {
            Section {
                HStack {
                    TextField("Username", text: $model.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Random", systemImage: "dice", action: model.useRandomUsername)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                TextField("Card label", text: $model.cardLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PINInputSection(
                    title: "PIN", source: $model.pinSource, custom: $model.customPIN,
                    sources: PINSource.allCases, hasStoredPIN: model.hasStoredPIN
                )
                Toggle("Discoverable credential (rk)", isOn: $model.residentKey)
            } header: {
                Text("Setup")
            } footer: {
                PINScreenFooter(needsNFC: model.needsNFC, setupError: model.setupError,
                                note: "The card needs a PIN already (use Set PIN). A wrong PIN costs one retry.")
            }
        } results: {
            if let outcome = model.outcome, let trace = model.runner.latestTrace {
                ChecksListView(checks: outcome.checks, saveError: outcome.saveError)
                CredentialLinksSection(
                    credential: outcome.credential,
                    details: outcome.credential.flatMap { model.environment.credentialStore.details(for: $0.id) },
                    traceID: trace.id, environment: model.environment)
            }
        }
    }
}
