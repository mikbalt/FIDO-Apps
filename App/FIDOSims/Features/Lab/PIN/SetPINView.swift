import SwiftUI

/// Set PIN on a card without one, e.g. after a reset.
struct SetPINView: View {
    @Bindable var model: SetPINViewModel

    var body: some View {
        ScenarioScreen(title: "Set PIN", model: model.runner, runTitle: "Set PIN", canRun: model.canRun, run: model.run) {
            Section {
                TextField("Card label", text: $model.cardLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                PINInputSection(
                    title: "New PIN", source: $model.source, custom: $model.customPIN,
                    sources: [.defaultPIN, .custom], hasStoredPIN: false
                )
                Toggle("Store PIN", isOn: $model.storePIN)
            } header: {
                Text("Setup")
            } footer: {
                PINScreenFooter(needsNFC: model.needsNFC, setupError: model.setupError,
                                note: "Fails before any PIN command if the card already has a PIN.")
            }
        }
    }
}
