import FIDOKit
import SwiftUI

/// Timing tiles, warnings and the trace in Hex, Safe or Decoded form.
struct TraceResultSections: View {
    @Binding var displayMode: ExchangeDisplayMode
    let trace: Trace
    let metrics: TraceMetrics

    var body: some View {
        Section("Timing") {
            MetricTilesView(metrics: metrics)
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }

        if !trace.warnings.isEmpty {
            WarningListView(warnings: trace.warnings)
        }

        if displayMode == .decoded {
            DecodedTraceView(trace: trace, header: modePicker)
        } else {
            Section {
                TraceListView(exchanges: trace.exchanges, hidesSensitive: displayMode.hidesSensitive)
            } header: {
                modePicker
            } footer: {
                footer
            }
        }
    }

    private var modePicker: some View {
        HStack {
            Text("Exchanges")
            Spacer()
            Picker("Display", selection: $displayMode) {
                ForEach(ExchangeDisplayMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private var footer: some View {
        Text("\(trace.card.label) · \(trace.transport.rawValue) · \(trace.device.model) \(trace.device.os)")
    }
}
