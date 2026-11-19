import SwiftUI

/// Seconds since `start`, updating live until `end` is set.
struct ElapsedTimeView: View {
    let start: Date
    let end: Date?

    var body: some View {
        if let end {
            label(end.timeIntervalSince(start))
        } else {
            TimelineView(.periodic(from: start, by: 0.1)) { context in
                label(context.date.timeIntervalSince(start))
            }
        }
    }

    private func label(_ seconds: TimeInterval) -> some View {
        Text("\(max(seconds, 0), format: .number.precision(.fractionLength(1))) s")
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }
}
