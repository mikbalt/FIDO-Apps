import FIDOKit
import SwiftUI

/// One registration: credential ID, public key, flags and AAGUID.
struct RegistrationDetailView: View {
    let credential: StoredCredential
    let details: RegistrationDetails?

    var body: some View {
        List {
            if credential.invalidated {
                Section {
                    Label("The card was reset. It no longer holds this credential's private key.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            Section("Credential") {
                row("Username", credential.username)
                row("Card", credential.cardLabel)
                row("RP", credential.rpId)
                row("Discoverable", credential.discoverable ? "Yes" : "No")
                row("Attestation", "\(credential.attestationFormat) (not verified)")
                row("signCount", "\(credential.signCount)")
                row("Created", credential.createdAt.formatted(date: .abbreviated, time: .standard))
                row("Last used", credential.lastUsedAt?.formatted(date: .abbreviated, time: .standard) ?? "never")
            }
            Section("Binary") {
                hex("Credential ID", credential.credentialId)
                hex("User handle", credential.userHandle)
                hex("Public key (COSE)", credential.publicKeyCOSE)
                hex("AAGUID", details?.aaguid)
                row("Registration flags", details.map { String(format: "0x%02X", $0.flags) } ?? "—")
            }
        }
        .navigationTitle(credential.username)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }

    private func hex(_ title: String, _ data: Data?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(data.map { Hex.compact($0) } ?? "—")
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .combine)
    }
}
