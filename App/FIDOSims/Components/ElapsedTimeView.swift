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
        Text(Self.format(seconds))
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    /// Seconds with one fixed `.` decimal, whatever the device locale, e.g. `0.3 s`.
    static func format(_ seconds: TimeInterval) -> String {
        let tenths = Int((max(seconds, 0) * 10).rounded())
        return "\(tenths / 10).\(tenths % 10) s"
    }
}
