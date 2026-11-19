import SwiftUI

/// The state of a run, with its icon, an optional note and the elapsed time.
struct RunStatusView: View {
    let title: String
    let systemImage: String
    let tint: Color
    let note: String?
    let isActive: Bool
    let startedAt: Date?
    let endedAt: Date?

    var body: some View {
        HStack {
            if isActive {
                ProgressView()
                    .padding(.trailing, 4)
            } else {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let startedAt {
                ElapsedTimeView(start: startedAt, end: endedAt)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
