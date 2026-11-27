import FIDOKit
import SwiftUI

/// The RP's named checks, with pass or fail and the detail.
struct ChecksListView: View {
    let checks: [RPCheck]
    let saveError: String?

    var body: some View {
        Section {
            ForEach(checks) { check in
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(check.passed ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(check.name.rawValue)
                        Text(check.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(check.name.rawValue): \(check.passed ? "passed" : "failed"). \(check.detail)")
            }
            if let saveError {
                Text("Could not save: \(saveError)").foregroundStyle(.red)
            }
        } header: {
            Text("RP checks (\(checks.filter(\.passed).count) of \(checks.count) passed)")
        } footer: {
            Text("The local RP is part of this app. The attestation format is recorded, not verified. Not verified on a real card.")
        }
    }
}
