import SwiftUI

/// Change PIN: SELECT, GetInfo, retries, key agreement, changePIN.
struct ChangePINView: View {
    @Bindable var model: ChangePINViewModel

    var body: some View {
        ScenarioScreen(title: "Change PIN", model: model.runner, runTitle: "Change PIN", canRun: model.canRun, run: model.run) {
            Section {
                TextField("Card label", text: $model.cardLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PINInputSection(
                    title: "Current PIN", source: $model.currentSource, custom: $model.customCurrent,
                    sources: PINSource.allCases, hasStoredPIN: model.hasStoredPIN
                )
                SecureField("New PIN", text: $model.newPIN)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.asciiCapable)
                    .accessibilityLabel("New PIN")
                Toggle("Store PIN", isOn: $model.storePIN)
            } header: {
                Text("Setup")
            } footer: {
                PINScreenFooter(needsNFC: model.needsNFC, setupError: model.setupError,
                                note: "A wrong current PIN costs one retry. Never run retries down to 0 on a card you cannot reset.")
            }
        }
    }
}
