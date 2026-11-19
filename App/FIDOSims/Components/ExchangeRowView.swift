import FIDOKit
import SwiftUI

/// One physical exchange: index, label, RTT, TX/RX bytes and status word.
struct ExchangeRowView: View {
    let exchange: ExchangeEvent
    let hidesSensitive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(exchange.index, format: .number.precision(.integerLength(2...)))
                    .foregroundStyle(.secondary)
                Text(exchange.label)
                    .fontWeight(.semibold)
                if exchange.sensitive {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Sensitive")
                }
                Spacer()
                Text(TimingFormat.milliseconds(exchange.rtt))
                    .monospacedDigit()
            }
            .font(.subheadline)

            bytesLine("TX", exchange.txDisplay(hideSensitive: hidesSensitive))
            bytesLine("RX", exchange.rx.isEmpty ? "—" : exchange.rxDisplay(hideSensitive: hidesSensitive))

            HStack(spacing: 6) {
                Text("SW \(exchange.sw.hex)")
                    .fontWeight(.medium)
                    .foregroundStyle(exchange.sw.isSuccess ? .green : .orange)
                if let name = exchange.sw.displayName {
                    Text(name)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospaced())
        }
        .padding(.vertical, 2)
    }

    private func bytesLine(_ title: String, _ bytes: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(bytes)
                .textSelection(.enabled)
        }
        .font(.caption.monospaced())
    }
}
