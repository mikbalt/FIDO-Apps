import FIDOKit
import SwiftUI

/// Timing tiles, warnings and the trace in Hex, Safe or Decoded form, for the selected trace.
struct TraceResultSections: View {
    @Bindable var model: ScenarioRunModel
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

        if model.displayMode == .decoded {
            DecodedTraceView(trace: trace, header: modePicker)
        } else {
            Section {
                TraceListView(exchanges: trace.exchanges, hidesSensitive: model.displayMode.hidesSensitive)
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
            Picker("Display", selection: $model.displayMode) {
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
