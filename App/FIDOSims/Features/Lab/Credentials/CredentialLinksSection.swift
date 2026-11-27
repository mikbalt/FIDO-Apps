import FIDOKit
import SwiftUI

/// "View registration" and "View log" for a finished run.
struct CredentialLinksSection: View {
    let credential: StoredCredential?
    let details: RegistrationDetails?
    let traceID: Trace.ID
    let environment: LabEnvironment

    var body: some View {
        Section {
            if let credential {
                NavigationLink("View registration") {
                    RegistrationDetailView(credential: credential, details: details)
                }
            }
            NavigationLink("View log") {
                HistoryView(model: HistoryViewModel(store: environment.traceStore, selecting: traceID))
            }
        }
    }
}
