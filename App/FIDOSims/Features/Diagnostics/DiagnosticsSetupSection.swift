import FIDOKit
import SwiftUI

/// Transport, fixture, length form and card label.
struct DiagnosticsSetupSection: View {
    @Bindable var model: DiagnosticsViewModel

    var body: some View {
        Section {
            Picker("Transport", selection: $model.transportChoice) {
                ForEach(TransportChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            .disabled(model.isMockForced)

            if model.transportChoice == .mock {
                Picker("Fixture", selection: $model.selectedFixtureID) {
                    ForEach(model.fixtures) { fixture in
                        Text(fixture.title).tag(Optional(fixture.id))
                    }
                }
                Toggle("Replay in real time", isOn: $model.realtimeReplay)
            }

            Picker("APDU length", selection: $model.lengthForm) {
                Text("Short").tag(LengthForm.short)
                Text("Extended").tag(LengthForm.extended)
            }
            .pickerStyle(.segmented)
            .disabled(model.transportChoice == .mock)

            TextField("Card label", text: $model.cardLabel)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Setup")
        } footer: {
            if model.isMockForced {
                Text("NFC is not available here, so runs use the mock transport.")
            } else if model.transportChoice == .mock {
                Text("Mock runs replay the fixture's own length form.")
            }
        }
        .disabled(model.state.isRunning)
    }
}
