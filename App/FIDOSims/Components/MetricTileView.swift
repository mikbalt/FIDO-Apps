import SwiftUI

/// One labeled value, e.g. "Card wait / 1503.000 ms".
struct MetricTileView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.fill.tertiary, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MetricTileView(title: "Card wait", value: "1503.000 ms")
        .padding()
}
