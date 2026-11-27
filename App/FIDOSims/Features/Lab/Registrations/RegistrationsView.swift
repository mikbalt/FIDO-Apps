import FIDOKit
import SwiftUI

/// Lab › Registrations: what the local RP has stored.
struct RegistrationsView: View {
    let model: RegistrationsViewModel

    var body: some View {
        List {
            if let error = model.error {
                Text(error).foregroundStyle(.red)
            }
            if model.credentials.isEmpty {
                Text("No registrations yet. Use Register to make one.")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.credentials) { credential in
                NavigationLink {
                    RegistrationDetailView(credential: credential, details: model.details(for: credential))
                } label: {
                    RegistrationRowView(credential: credential)
                }
            }
            .onDelete { offsets in
                for offset in offsets {
                    model.delete(model.credentials[offset])
                }
            }
        }
        .navigationTitle("Registrations")
        .onAppear { model.reload() }
    }
}
