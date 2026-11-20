import SwiftUI

/// Reset the card: wipes every credential and the PIN. Run is enabled only after the label is typed again.
struct ResetView: View {
    @Bindable var model: ResetViewModel

    var body: some View {
        ScenarioScreen(title: "Reset", model: model.runner, runTitle: "Reset card", canRun: model.canRun, run: model.run) {
            Section {
                TextField("Card label", text: $model.cardLabel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Type the card label to confirm", text: $model.confirmation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Setup")
            } footer: {
                PINScreenFooter(needsNFC: model.needsNFC, setupError: model.setupError,
                                note: "Wipes all credentials and the PIN. Tap the card right after starting: "
                                    + "the card accepts reset only within about 10 s of entering the field.")
            }
        }
    }
}
