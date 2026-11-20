import FIDOKit
import SwiftUI

/// Trace warnings, shown above the exchanges.
struct WarningListView: View {
    let warnings: [WarningEvent]

    var body: some View {
        Section("Warnings") {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.code.rawValue)
                            .font(.caption.monospaced().weight(.semibold))
                        Text(warning.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
