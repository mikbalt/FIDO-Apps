import FIDOKit
import SwiftUI

struct RegistrationRowView: View {
    let credential: StoredCredential

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(credential.username)
                if credential.invalidated {
                    Text("invalidated")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.2), in: .capsule)
                        .foregroundStyle(.orange)
                }
            }
            Text("\(credential.cardLabel) · created \(credential.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Last used \(credential.lastUsedAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "never") · signCount \(credential.signCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
